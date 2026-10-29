package vn.gomate;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.*;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import vn.gomate.auth.*;
import vn.gomate.common.*;
import vn.gomate.notification.realtime.*;
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
class NotificationRealtimeTest {
 @Autowired MockMvc mvc;
 @Autowired ObjectMapper json;
 @Autowired AuthService auth;
 @Autowired TripService trips;
 @Autowired NotificationService inbox;
 @Autowired Db db;
 @Autowired PlatformTransactionManager transactions;
 @Autowired NotificationEventPublisher events;
 @MockitoSpyBean NotificationStreamHub streams;
 private final List<MvcResult> openStreams=new ArrayList<>();

 @AfterEach void cleanup() {
  openStreams.forEach(r -> r.getRequest().getAsyncContext().complete());
  db.update("DELETE FROM notifications",Map.of());
  db.update("DELETE FROM conversations WHERE type='GROUP'",Map.of());
  db.update("DELETE FROM trips",Map.of());
 }

 @Test void streamUsesBearerPrincipalAndRejectsRecipientSelection() throws Exception {
  var a=user(); var b=user();
  mvc.perform(get("/api/v1/notifications/stream")).andExpect(status().isUnauthorized());
  mvc.perform(get("/api/v1/notifications/stream").header("Authorization",a.bearer())
   .param("recipientUserId",b.id().toString())).andExpect(status().isBadRequest());
  var aStream=connect(a); var bStream=connect(b);
  var signal=new NotificationSignal(UUID.randomUUID(),"UPDATED",UUID.randomUUID(),Instant.now());
  streams.publish(b.id(),signal);
  await().atMost(Duration.ofSeconds(3)).untilAsserted(() -> assertTrue(body(bStream).contains(signal.eventId().toString())));
  assertFalse(body(aStream).contains(signal.eventId().toString()));
  assertTrue(body(bStream).contains("event:notification"));
  assertFalse(body(bStream).contains("Bearer"));
 }

 @Test void eventWaitsForOuterCommitAndRollbackEmitsNothing() {
  var a=user(); var b=user();
  var tx=new TransactionTemplate(transactions);
  tx.executeWithoutResult(status -> {
   trips.create(a.id(),createRequest(List.of(b.id())));
   verify(streams,never()).publish(any(),any());
  });
  verify(streams).publish(eq(b.id()),argThat(s -> s.eventKind().equals("CREATED") && s.notificationId()!=null));
  clearInvocations(streams);
  long before=inbox.list(b.id(),0,30).total();
  tx.executeWithoutResult(status -> {
   trips.create(a.id(),createRequest(List.of(b.id())));
   status.setRollbackOnly();
  });
  verify(streams,never()).publish(any(),any());
  assertEquals(before,inbox.list(b.id(),0,30).total());
 }

 @Test void acceptSignalsBothCommittedRecipientStateAndInviterInboxOnlyOnce() {
  var a=user(); var b=user(); var stranger=user();
  var trip=trips.create(a.id(),createRequest(List.of(b.id())));
  UUID invitationId=trip.pendingInvitations().get(0).invitationId();
  clearInvocations(streams);
  doAnswer(call -> {
   assertEquals("ACCEPTED",inbox.list(b.id(),0,30).items().get(0).invitationStatus());
   assertEquals(2,db.count("SELECT COUNT(*) FROM trip_members WHERE trip_id=:id",args("id",trip.id())));
   return null;
  }).when(streams).publish(any(),any());
  assertThrows(ApiException.class,() -> trips.acceptInvitation(stranger.id(),invitationId));
  verify(streams,never()).publish(any(),any());
  trips.acceptInvitation(b.id(),invitationId);
  verify(streams).publish(eq(b.id()),argThat(s -> s.eventKind().equals("UPDATED")));
  verify(streams).publish(eq(a.id()),argThat(s -> s.eventKind().equals("CREATED")));
  verify(streams,never()).publish(eq(stranger.id()),any());
  clearInvocations(streams);
  trips.acceptInvitation(b.id(),invitationId);
  assertThrows(ApiException.class,() -> trips.cancelInvitation(a.id(),trip.id(),invitationId));
  verify(streams,never()).publish(any(),any());
 }

 @Test void cancelUpdatesOriginalNotificationAndReinviteHasDistinctIdentity() {
  var a=user(); var b=user(); var stranger=user();
  var trip=trips.create(a.id(),createRequest(List.of(b.id())));
  var original=inbox.list(b.id(),0,30).items().get(0);
  clearInvocations(streams);
  assertThrows(ApiException.class,() -> trips.cancelInvitation(stranger.id(),trip.id(),original.invitationId()));
  verify(streams,never()).publish(any(),any());
  trips.cancelInvitation(a.id(),trip.id(),original.invitationId());
  verify(streams).publish(eq(b.id()),argThat(s -> s.eventKind().equals("UPDATED") && s.notificationId().equals(original.id())));
  assertEquals("CANCELLED",inbox.detail(b.id(),original.id()).invitationStatus());
  clearInvocations(streams);
  trips.cancelInvitation(a.id(),trip.id(),original.invitationId());
  assertThrows(ApiException.class,() -> trips.acceptInvitation(b.id(),original.invitationId()));
  verify(streams,never()).publish(any(),any());
  var again=trips.createInvitation(a.id(),trip.id(),new TripDtos.CreateInvitationRequest(b.id()));
  assertNotEquals(original.invitationId(),again.invitationId());
  verify(streams).publish(eq(b.id()),argThat(s -> s.eventKind().equals("CREATED") && !s.notificationId().equals(original.id())));
  assertEquals(2,inbox.list(b.id(),0,30).total());
  assertEquals(1,trips.detail(a.id(),trip.id()).memberCount());
  assertNull(trips.detail(a.id(),trip.id()).linkedConversationId());
 }

 @Test void failedTransactionAndDeliveryOutageCannotProduceFalseBusinessState() {
  var a=user(); var b=user();
  var tx=new TransactionTemplate(transactions);
  var trip=trips.create(a.id(),createRequest(List.of(b.id())));
  UUID id=trip.pendingInvitations().get(0).invitationId();
  clearInvocations(streams);
  tx.executeWithoutResult(status -> {
   trips.acceptInvitation(b.id(),id);
   status.setRollbackOnly();
  });
  verify(streams,never()).publish(any(),any());
  assertEquals("PENDING",inbox.list(b.id(),0,30).items().get(0).invitationStatus());
  tx.executeWithoutResult(status -> {
   trips.cancelInvitation(a.id(),trip.id(),id);
   status.setRollbackOnly();
  });
  verify(streams,never()).publish(any(),any());
  doThrow(new IllegalStateException("transport unavailable")).when(streams).publish(any(),any());
  assertDoesNotThrow(() -> trips.cancelInvitation(a.id(),trip.id(),id));
  assertEquals("CANCELLED",inbox.list(b.id(),0,30).items().get(0).invitationStatus());
  assertDoesNotThrow(() -> trips.createInvitation(a.id(),trip.id(),new TripDtos.CreateInvitationRequest(b.id())));
  var newId=trips.detail(a.id(),trip.id()).pendingInvitations().get(0).invitationId();
  assertDoesNotThrow(() -> trips.acceptInvitation(b.id(),newId));
  assertEquals(2,trips.detail(a.id(),trip.id()).memberCount());
  assertEquals(1,inbox.list(a.id(),0,30).total());
 }

 @Test void readStateInvalidatesOtherSessionsAndNonTransactionalSignalsAreIgnored() {
  var a=user(); var b=user();
  trips.create(a.id(),createRequest(List.of(b.id())));
  var id=inbox.list(b.id(),0,30).items().get(0).id();
  clearInvocations(streams);
  events.changed(b.id(),id,"UPDATED");
  verify(streams,never()).publish(any(),any());
  inbox.markRead(b.id(),id);
  verify(streams).publish(eq(b.id()),argThat(s -> s.eventKind().equals("UPDATED") && s.notificationId().equals(id)));
 }

 private MvcResult connect(User user) throws Exception {
  var result=mvc.perform(get("/api/v1/notifications/stream").header("Authorization",user.bearer()))
   .andExpect(status().isOk()).andExpect(request().asyncStarted())
   .andExpect(header().string("X-Accel-Buffering","no")).andReturn();
  openStreams.add(result);
  return result;
 }
 private String body(MvcResult result) throws Exception { return result.getResponse().getContentAsString(); }
 private TripDtos.CreateTripRequest createRequest(List<UUID> invitees) {
  return json.convertValue(Map.of("title","Realtime integration","startDate","2026-12-01","endDate","2026-12-02","selectedMemberIds",invitees),TripDtos.CreateTripRequest.class);
 }
 private User user() {
  String suffix=UUID.randomUUID().toString().replace("-","");
  var session=auth.register(new AuthDtos.Register("realtime-"+suffix+"@example.invalid","TestPass123!","rt_"+suffix.substring(0,10)));
  return new User((UUID)((Map<?,?>)session.get("user")).get("id"),"Bearer "+session.get("accessToken"));
 }
 private record User(UUID id,String bearer) {}
}
