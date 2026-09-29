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

    void delete(String publicId, MediaResourceType resourceType) throws IOException;
}
