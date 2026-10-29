package vn.gomate.notification.realtime;

import java.time.Instant;
import java.util.UUID;

/** Delivery hint only. REST/PostgreSQL remains authoritative. */
public record NotificationSignal(UUID eventId,String eventKind,UUID notificationId,Instant occurredAt) {}
