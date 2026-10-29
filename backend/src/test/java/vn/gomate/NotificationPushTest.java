package vn.gomate;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.*;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import vn.gomate.auth.*;
import vn.gomate.common.Db;
import vn.gomate.notification.push.*;
import vn.gomate.notification.repository.NotificationDeviceRepository;
import vn.gomate.notification.service.NotificationService;
import vn.gomate.trip.dto.TripDtos;
import vn.gomate.trip.service.TripService;
import static org.awaitility.Awaitility.await;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static vn.gomate.common.Db.args;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class NotificationPushTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired TripService trips;
 @Autowired NotificationService inbox;
 @Autowired NotificationDeviceRepository devices;
 @Autowired PlatformTransactionManager transactions;
 @Autowired Db db;
 @MockitoBean FcmGateway fcm;
 @MockitoSpyBean NotificationPushDelivery push;

 @BeforeEach void setup() { when(fcm.send(any(),any(),any(),any())).thenReturn(FcmGateway.Result.SENT); }
 @AfterEach void cleanup() {
  db.update("DELETE FROM device_tokens",Map.of());
  db.update("DELETE FROM notifications",Map.of());
  db.update("DELETE FROM conversations WHERE type='GROUP'",Map.of());
  db.update("DELETE FROM trips",Map.of());
 }

 @Test void registrationIsAuthenticatedOwnedIdempotentAndRotatesOneInstallation() throws Exception {
  var a=user(); UUID install=UUID.randomUUID();
  mvc.perform(post("/api/v1/notification-devices").contentType("application/json").content(json.writeValueAsBytes(body(install,"token-one"))))
   .andExpect(status().isUnauthorized());
  var forged=new HashMap<>(body(install,"token-one")); forged.put("userId",UUID.randomUUID());
  mvc.perform(post("/api/v1/notification-devices").header("Authorization",a.bearer()).contentType("application/json")
   .content(json.writeValueAsBytes(forged))).andExpect(status().isBadRequest());
  register(a,install,"token-one"); register(a,install,"token-one");
  assertEquals(1,devices.activeAndroid(a.id()).size());
  register(a,install,"token-two");
  var row=devices.activeAndroid(a.id()).get(0);
  assertEquals("token-two",row.get("token"));
  assertEquals(1,db.count("SELECT COUNT(*) FROM device_tokens WHERE installation_id=:id",args("id",install)));
  mvc.perform(get("/api/v1/notification-devices/"+UUID.randomUUID()).header("Authorization",a.bearer())).andExpect(status().isNotFound());
 }

 @Test void unregisterAndAccountSwitchDoNotDisableAnotherActiveBinding() throws Exception {
  var a=user(); var b=user(); UUID install=UUID.randomUUID(); UUID second=UUID.randomUUID();
  register(a,install,"shared-install"); register(a,second,"other-device");
  unregister(b,install);
  assertEquals(2,devices.activeAndroid(a.id()).size());
  register(b,install,"new-owner-token");
  unregister(a,install); // Late cleanup from the previous owner/session.
  assertEquals(1,devices.activeAndroid(a.id()).size());
  assertEquals(1,devices.activeAndroid(b.id()).size());
  unregister(b,install); unregister(b,install);
  assertTrue(devices.activeAndroid(b.id()).isEmpty());
  assertEquals(1,devices.activeAndroid(a.id()).size());
 }

 @Test void revokedSessionAndDisabledPushSettingExcludeDevicesWithoutRemovingInbox() throws Exception {
  var a=user(); var b=user();
  register(b,UUID.randomUUID(),"session-token");
  mvc.perform(post("/api/v1/auth/logout").header("Authorization",b.bearer())).andExpect(status().isNoContent());
  assertTrue(devices.activeAndroid(b.id()).isEmpty());
  trips.create(a.id(),create(List.of(b.id())));
  assertEquals(1,inbox.list(b.id(),0,30).total());
  var c=user(); register(c,UUID.randomUUID(),"setting-token");
  db.update("UPDATE user_settings SET notifications_enabled=FALSE WHERE user_id=:id",args("id",c.id()));
  assertTrue(devices.activeAndroid(c.id()).isEmpty());
 }

 @Test void pushRunsOnlyAfterCommitAndRollbackNeverEnqueues() throws Exception {
  var a=user(); var b=user(); register(b,UUID.randomUUID(),"commit-token");
  var tx=new TransactionTemplate(transactions);
  tx.executeWithoutResult(status -> {
   trips.create(a.id(),create(List.of(b.id())));
   verify(push,never()).enqueue(any(),any());
   verifyNoInteractions(fcm);
  });
  await().atMost(Duration.ofSeconds(3)).untilAsserted(() -> verify(fcm).send(eq("commit-token"),eq(b.id()),any(),any()));
  clearInvocations(push,fcm);
  tx.executeWithoutResult(status -> {
   trips.create(a.id(),create(List.of(b.id())));
   status.setRollbackOnly();
  });
  verify(push,never()).enqueue(any(),any());
  verifyNoInteractions(fcm);
 }

 @Test void newInviteSelectsInviteeAndAcceptSelectsInviterNotUnrelatedDevices() throws Exception {
  var a=user(); var b=user(); var c=user();
  register(a,UUID.randomUUID(),"inviter-token"); register(b,UUID.randomUUID(),"invitee-token"); register(c,UUID.randomUUID(),"unrelated-token");
  var trip=trips.create(a.id(),create(List.of(b.id())));
  UUID inviteId=trip.pendingInvitations().get(0).invitationId();
  UUID notificationId=inbox.list(b.id(),0,30).items().get(0).id();
  await().atMost(Duration.ofSeconds(3)).untilAsserted(() -> verify(fcm).send(eq("invitee-token"),eq(b.id()),eq(notificationId),any()));
  verify(fcm,never()).send(eq("inviter-token"),any(),any(),any());
  trips.acceptInvitation(b.id(),inviteId);
  await().atMost(Duration.ofSeconds(3)).untilAsserted(() -> verify(fcm).send(eq("inviter-token"),eq(a.id()),any(),any()));
  verify(fcm,never()).send(eq("unrelated-token"),any(),any(),any());
  assertEquals("ACCEPTED",inbox.detail(b.id(),notificationId).invitationStatus());
 }

 @Test void fcmFailureDoesNotRollbackAndCancellationHasNoNewPush() throws Exception {
  var a=user(); var b=user(); register(b,UUID.randomUUID(),"failing-token");
  when(fcm.send(any(),any(),any(),any())).thenThrow(new IllegalStateException("simulated FCM outage"));
  var trip=assertDoesNotThrow(() -> trips.create(a.id(),create(List.of(b.id()))));
  await().atMost(Duration.ofSeconds(3)).untilAsserted(() -> verify(fcm).send(eq("failing-token"),eq(b.id()),any(),any()));
  assertEquals(1,inbox.list(b.id(),0,30).total());
  clearInvocations(fcm);
  var original=inbox.list(b.id(),0,30).items().get(0);
  trips.cancelInvitation(a.id(),trip.id(),original.invitationId());
  verifyNoInteractions(fcm);
  assertEquals("CANCELLED",inbox.detail(b.id(),original.id()).invitationStatus());
  assertEquals(1,trips.detail(a.id(),trip.id()).memberCount());
 }

 @Test void unregisteredTokenCleanupIsConditionalAndPreservesOtherTokens() throws Exception {
  var a=user(); var b=user(); UUID first=UUID.randomUUID(); UUID second=UUID.randomUUID();
  register(b,first,"invalid-token"); register(b,second,"valid-token");
  when(fcm.send(eq("invalid-token"),any(),any(),any())).thenReturn(FcmGateway.Result.UNREGISTERED);
  trips.create(a.id(),create(List.of(b.id())));
  await().atMost(Duration.ofSeconds(3)).untilAsserted(() -> assertEquals(1,devices.activeAndroid(b.id()).size()));
  assertEquals("valid-token",devices.activeAndroid(b.id()).get(0).get("token"));
  var row=devices.activeAndroid(b.id()).get(0);
  register(b,second,"rotated-token");
  devices.invalidToken((UUID)row.get("id"),b.id(),(UUID)row.get("sessionId"),"valid-token");
  assertEquals("rotated-token",devices.activeAndroid(b.id()).get(0).get("token"));
 }

 @Test void migrationTwelveAddsOnlyDeviceTokensAndHasUniqueTokenConstraint() throws Exception {
  assertEquals(1,db.count("SELECT COUNT(*) FROM flyway_schema_history WHERE success=TRUE AND version='12'",Map.of()));
  assertEquals(1,db.count("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='device_tokens'",Map.of()));
  var a=user(); var b=user();
  register(a,UUID.randomUUID(),"same-fcm-token");
  register(b,UUID.randomUUID(),"same-fcm-token");
  assertTrue(devices.activeAndroid(a.id()).isEmpty());
  assertEquals(1,devices.activeAndroid(b.id()).size());
 }

 @Test void tripReminderDaysUseSeparatePushIdsAndRespectPushPreference() throws Exception {
  var a=user(); var b=user();
  register(a,UUID.randomUUID(),"reminder-token"); register(b,UUID.randomUUID(),"disabled-reminder-token");
  db.update("UPDATE user_settings SET notifications_enabled=FALSE WHERE user_id=:id",args("id",b.id()));
  var trip=trips.create(a.id(),create(List.of()));
  for(var recipient:List.of(a,b)) {
   var target=recipient==a?trip:trips.create(b.id(),create(List.of()));
   for(int days:new int[]{2,1}) {
    UUID reminder=(UUID)db.one("SELECT id FROM trip_reminders WHERE trip_id=:trip AND recipient_user_id=:user AND days_before=:days",
     args("trip",target.id(),"user",recipient.id(),"days",days)).get("id");
    db.update("UPDATE trip_reminders SET status='SENT',sent_at=CURRENT_TIMESTAMP WHERE id=:id",args("id",reminder));
    inbox.recordTripDateReminder(recipient.id(),reminder,"Push reminder fixture",days,target.startDate());
   }
  }
  await().atMost(Duration.ofSeconds(3)).untilAsserted(() -> verify(fcm,times(2)).send(eq("reminder-token"),eq(a.id()),any(),contains("chuẩn bị")));
  verify(fcm,never()).send(eq("disabled-reminder-token"),any(),any(),any());
  var notices=inbox.list(a.id(),0,30).items();
  assertEquals(2,notices.size()); assertNotEquals(notices.get(0).id(),notices.get(1).id());
  assertNotEquals(notices.get(0).reminderId(),notices.get(1).reminderId());
  assertTrue(notices.stream().allMatch(n -> n.invitationId()==null && n.tripId().equals(trip.id())));
  assertEquals(2,inbox.list(b.id(),0,30).total());
 }

 private Map<String,Object> body(UUID install,String token) { return Map.of("installationId",install,"token",token,"platform","ANDROID"); }
 private void register(User user,UUID install,String token) throws Exception {
  mvc.perform(post("/api/v1/notification-devices").header("Authorization",user.bearer()).contentType("application/json")
   .content(json.writeValueAsBytes(body(install,token)))).andExpect(status().isNoContent());
 }
 private void unregister(User user,UUID install) throws Exception {
  mvc.perform(delete("/api/v1/notification-devices/current").header("Authorization",user.bearer()).contentType("application/json")
   .content(json.writeValueAsBytes(Map.of("installationId",install)))).andExpect(status().isNoContent());
 }
 private TripDtos.CreateTripRequest create(List<UUID> invitees) {
  return json.convertValue(Map.of("title","Push integration","startDate","2026-12-01","endDate","2026-12-02","selectedMemberIds",invitees),TripDtos.CreateTripRequest.class);
 }
 private User user() {
  String suffix=UUID.randomUUID().toString().replace("-","");
  var session=auth.register(new AuthDtos.Register("push-"+suffix+"@example.invalid","TestPass123!","push_"+suffix.substring(0,8)));
  return new User((UUID)((Map<?,?>)session.get("user")).get("id"),"Bearer "+session.get("accessToken"));
 }
 private record User(UUID id,String bearer) {}
}
