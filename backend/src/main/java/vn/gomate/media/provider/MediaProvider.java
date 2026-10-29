package vn.gomate.media.provider;

import java.io.IOException;
import org.springframework.web.multipart.MultipartFile;
import vn.gomate.media.dto.MediaUploadResult;
import vn.gomate.media.model.MediaResourceType;

public interface MediaProvider {
    MediaUploadResult uploadImage(MultipartFile file, String folder) throws IOException;

    MediaUploadResult uploadRemoteImage(String imageUrl, String folder, String publicId) throws IOException;

    MediaUploadResult uploadImageBytes(byte[] bytes, String folder, String publicId, String contentType) throws IOException;

    MediaUploadResult uploadVideo(MultipartFile file, String folder) throws IOException;

    default MediaUploadResult uploadProtected(java.io.File file, String publicId, MediaResourceType type) throws IOException {
        throw new IOException("Protected Post media is unavailable");
    }
    default String protectedDownload(String publicId, String format, MediaResourceType type) throws IOException {
        throw new IOException("Protected Post delivery is unavailable");
    }
    default void deleteProtected(String publicId, MediaResourceType type) throws IOException {
        throw new IOException("Protected Post deletion is unavailable");
    }

    void delete(String publicId, MediaResourceType resourceType) throws IOException;
}
