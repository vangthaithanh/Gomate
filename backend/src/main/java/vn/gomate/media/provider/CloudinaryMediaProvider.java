package vn.gomate.media.provider;

import com.cloudinary.Cloudinary;
import com.cloudinary.utils.ObjectUtils;
import java.io.IOException;
import java.util.Map;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import vn.gomate.media.dto.MediaUploadResult;
import vn.gomate.media.model.MediaResourceType;

@Component
@ConditionalOnBean(Cloudinary.class)
public class CloudinaryMediaProvider implements MediaProvider {

    private final Cloudinary cloudinary;

    public CloudinaryMediaProvider(Cloudinary cloudinary) {
        this.cloudinary = cloudinary;
    }

    @Override
    public MediaUploadResult uploadImage(MultipartFile file, String folder) throws IOException {
        return upload(file, folder, "image", MediaResourceType.IMAGE);
    }

    @Override
    public MediaUploadResult uploadRemoteImage(String imageUrl, String folder, String publicId) throws IOException {
        Map<?, ?> result = cloudinary.uploader().upload(imageUrl, ObjectUtils.asMap(
            "folder", folder,
            "public_id", publicId,
            "overwrite", true,
            "resource_type", "image"
        ));
        return result(result, MediaResourceType.IMAGE);
    }

    @Override
    public MediaUploadResult uploadImageBytes(byte[] bytes, String folder, String publicId, String contentType) throws IOException {
        Map<?, ?> result = cloudinary.uploader().upload(bytes, ObjectUtils.asMap(
            "folder", folder,
            "public_id", publicId,
            "overwrite", true,
            "resource_type", "image"
        ));
        return result(result, MediaResourceType.IMAGE);
    }

    @Override
    public MediaUploadResult uploadVideo(MultipartFile file, String folder) throws IOException {
        return upload(file, folder, "video", MediaResourceType.VIDEO);
    }

    @Override
    public MediaUploadResult uploadProtected(java.io.File file, String publicId, MediaResourceType type) throws IOException {
        Map<?,?> response=cloudinary.uploader().upload(file,ObjectUtils.asMap(
            "public_id",publicId,"resource_type",cloudinaryResourceType(type),"type","authenticated","overwrite",false));
        return result(response,type);
    }

    @Override
    public String protectedDownload(String publicId,String format,MediaResourceType type) throws IOException {
        try {
            return cloudinary.privateDownload(publicId,format,ObjectUtils.asMap(
                "resource_type",cloudinaryResourceType(type),"type","authenticated",
                "expires_at",java.time.Instant.now().getEpochSecond()+30));
        } catch(Exception e) { throw new IOException("Protected media unavailable"); }
    }

    @Override
    public void deleteProtected(String publicId,MediaResourceType type) throws IOException {
        cloudinary.uploader().destroy(publicId,ObjectUtils.asMap(
            "resource_type",cloudinaryResourceType(type),"type","authenticated","invalidate",true));
    }

    @Override
    public void delete(String publicId, MediaResourceType resourceType) throws IOException {
        cloudinary.uploader().destroy(publicId, ObjectUtils.asMap(
            "resource_type", cloudinaryResourceType(resourceType)
        ));
    }

    private MediaUploadResult upload(
        MultipartFile file,
        String folder,
        String resourceType,
        MediaResourceType mediaResourceType
    ) throws IOException {
        Map<?, ?> result = cloudinary.uploader().upload(file.getBytes(), ObjectUtils.asMap(
            "folder", folder,
            "resource_type", resourceType
        ));
        return result(result, mediaResourceType);
    }

    private MediaUploadResult result(Map<?, ?> result, MediaResourceType mediaResourceType) {
        return new MediaUploadResult(
            text(result.get("secure_url")),
            text(result.get("public_id")),
            mediaResourceType,
            text(result.get("format")),
            integer(result.get("width")),
            integer(result.get("height")),
            longValue(result.get("bytes")),
            doubleValue(result.get("duration"))
        );
    }

    private static String cloudinaryResourceType(MediaResourceType resourceType) {
        return resourceType == MediaResourceType.VIDEO ? "video" : "image";
    }

    private static String text(Object value) {
        return value instanceof String text ? text : null;
    }

    private static Integer integer(Object value) {
        return value instanceof Number number ? number.intValue() : null;
    }

    private static Long longValue(Object value) {
        return value instanceof Number number ? number.longValue() : null;
    }

    private static Double doubleValue(Object value) {
        return value instanceof Number number ? number.doubleValue() : null;
    }
}
