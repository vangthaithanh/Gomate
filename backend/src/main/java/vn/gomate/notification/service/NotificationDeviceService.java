package vn.gomate.notification.service;

import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.notification.repository.NotificationDeviceRepository;

@Service
public class NotificationDeviceService {
 private final NotificationDeviceRepository devices;
 public NotificationDeviceService(NotificationDeviceRepository devices) { this.devices=devices; }
 @Transactional public void register(UUID userId,UUID sessionId,UUID installationId,String token,String platform) {
  devices.register(userId,sessionId,installationId,token.trim(),platform);
 }
 @Transactional public void unregister(UUID userId,UUID sessionId,UUID installationId) {
  devices.unregister(userId,sessionId,installationId);
 }
}
