package vn.gomate.media.service;

import java.io.IOException;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import vn.gomate.common.ApiException;
import vn.gomate.media.dto.MediaUploadResult;
import vn.gomate.media.model.MediaResourceType;
import vn.gomate.media.provider.MediaProvider;

@Service
@ConditionalOnBean(MediaProvider.class)
public class MediaService {

    private final MediaProvider provider;

    public MediaService(MediaProvider provider) {
        this.provider = provider;
    }

    public MediaUploadResult uploadImage(MultipartFile file, String folder) {
        try {
            return provider.uploadImage(file, folder);
        } catch (IOException e) {
            throw new ApiException(503, "MEDIA_UPLOAD_FAILED", "Không tải ảnh lên được. Vui lòng thử lại.");
        }
    }

    public MediaUploadResult uploadRemoteImage(String imageUrl, String folder, String publicId) {
        try {
            return provider.uploadRemoteImage(imageUrl, folder, publicId);
        } catch (IOException | RuntimeException e) {
            throw new ApiException(503, "MEDIA_UPLOAD_FAILED", "Không tải ảnh remote lên được. Vui lòng thử lại.", e);
        }
    }

    public MediaUploadResult uploadImageBytes(byte[] bytes, String folder, String publicId, String contentType) {
        try {
            return provider.uploadImageBytes(bytes, folder, publicId, contentType);
        } catch (IOException | RuntimeException e) {
            throw new ApiException(503, "MEDIA_UPLOAD_FAILED", "Không tải ảnh đã fetch lên được. Vui lòng thử lại.", e);
        }
    }

    public MediaUploadResult uploadVideo(MultipartFile file, String folder) {
        try {
            return provider.uploadVideo(file, folder);
        } catch (IOException e) {
            throw new ApiException(503, "MEDIA_UPLOAD_FAILED", "Không tải video lên được. Vui lòng thử lại.");
        }
    }

    public void delete(String publicId, MediaResourceType resourceType) {
        try {
            provider.delete(publicId, resourceType);
        } catch (IOException e) {
            throw new ApiException(503, "MEDIA_DELETE_FAILED", "Không xóa media được. Vui lòng thử lại.");
        }
    }
}
