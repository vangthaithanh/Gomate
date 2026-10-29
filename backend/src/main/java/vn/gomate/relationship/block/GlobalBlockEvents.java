package vn.gomate.relationship.block;

import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.*;
import vn.gomate.notification.realtime.*;
import vn.gomate.location.realtime.TripLocationStreamHub;

@Component
public class GlobalBlockEvents {
 private final NotificationStreamHub accounts;
 private final TripLocationStreamHub locations;
 public GlobalBlockEvents(NotificationStreamHub accounts,TripLocationStreamHub locations) {this.accounts=accounts;this.locations=locations;}
 @TransactionalEventListener(phase=TransactionPhase.AFTER_COMMIT)
 public void changed(GlobalBlockService.Changed change) {
  // No inbox, FCM, blocker identity, Trip state or global snapshot mutation.
  for(UUID user:new UUID[]{change.actor(),change.target()}) try {
   accounts.publish(user,new NotificationSignal(UUID.randomUUID(),"ACCESS_CHANGED",null,Instant.now()));
  } catch(RuntimeException failure) {org.slf4j.LoggerFactory.getLogger(getClass()).warn("Account access invalidation unavailable; authenticated reconnect will recheck");}
  try {locations.accessChanged(change.actor(),change.target());}
  catch(RuntimeException failure) {org.slf4j.LoggerFactory.getLogger(getClass()).warn("Location access invalidation unavailable; reconnect will recheck");}
 }
}
