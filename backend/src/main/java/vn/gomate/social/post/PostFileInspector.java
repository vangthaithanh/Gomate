package vn.gomate.social.post;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.springframework.stereotype.Component;
import vn.gomate.common.ApiException;

@Component
public class PostFileInspector {
 private final ObjectMapper json;
 public PostFileInspector(ObjectMapper json) { this.json=json; }
 public record Metadata(String mime,String format,int width,int height,Long durationMs,long bytes) {}
 public Metadata inspect(Path path,String kind,String declaredMime) {
  try {
   long size=Files.size(path);
   boolean video="VIDEO".equals(kind);
   if(!video && !"IMAGE".equals(kind)) throw ApiException.bad("Loại media không hợp lệ.");
   if(size<=0 || size>(video?100000000L:10000000L)) throw new ApiException(413,"POST_MEDIA_TOO_LARGE","Ảnh tối đa 10 MB, video tối đa 100 MB.");
   byte[] header;
   try(var in=Files.newInputStream(path)) { header=in.readNBytes(32); }
   String detected=null,format=null;
   if(header.length>=12) {
    String ascii=new String(header,java.nio.charset.StandardCharsets.ISO_8859_1);
    if((header[0]&255)==255 && (header[1]&255)==216 && (header[2]&255)==255) { detected="image/jpeg";format="jpg"; }
    else if(header[0]==(byte)137 && ascii.substring(1,4).equals("PNG")) {detected="image/png";format="png";}
    else if(ascii.startsWith("RIFF") && ascii.substring(8,12).equals("WEBP")) {detected="image/webp";format="webp";}
    else if(ascii.substring(4,8).equals("ftyp")) {
     String brand=ascii.substring(8,12);
     if(Set.of("heic","heix","mif1").contains(brand)) { detected="image/heic";format="heic"; }
     else {detected=brand.equals("qt  ")?"video/quicktime":"video/mp4";format=brand.equals("qt  ")?"mov":"mp4";}
    } else if(header[0]==0x1a && header[1]==0x45 && header[2]==(byte)0xdf && header[3]==(byte)0xa3) {detected="video/webm";format="webm";}
   }
   if(detected==null || !detected.equals(declaredMime) || video!=detected.startsWith("video/"))
    throw new ApiException(415,"INVALID_POST_MEDIA","Nội dung tệp không khớp MIME hoặc loại media.");
   var data=json.readTree(run(List.of("ffprobe","-v","error","-protocol_whitelist","file,pipe","-show_entries","stream=codec_type,width,height:format=duration","-of","json",path.toString()),20));
   var streams=data.path("streams");
   int width=0,height=0;
   for(var stream:streams) if("video".equals(stream.path("codec_type").asText())) {width=stream.path("width").asInt();height=stream.path("height").asInt();break;}
   if(width<=0 || height<=0) throw ApiException.bad("Không đọc được ảnh hoặc video.");
   Long duration=null;
   if(video) {
    double seconds=data.path("format").path("duration").asDouble(0);
    if(!Double.isFinite(seconds) || seconds<=0 || seconds>30.0) throw new ApiException(422,"POST_VIDEO_DURATION","Video đầu ra phải dài không quá 30 giây.");
    duration=(long)Math.ceil(seconds*1000);
   }
   return new Metadata(detected,format,width,height,duration,size);
  } catch(ApiException e) {throw e;}
  catch(Exception e) {throw new ApiException(422,"POST_MEDIA_INSPECTION_FAILED","Không kiểm chứng được tệp media. Vui lòng thử tệp khác.");}
 }
 public void thumbnail(Path source,Path target) {
  try { run(List.of("ffmpeg","-nostdin","-v","error","-protocol_whitelist","file,pipe","-i",source.toString(),"-frames:v","1","-vf","scale=600:-2","-an","-y",target.toString()),30); }
  catch(Exception e) {throw new ApiException(422,"POST_THUMBNAIL_FAILED","Không tạo được ảnh xem trước.");}
 }
 private byte[] run(List<String> command,int seconds) throws Exception {
  Path output=Files.createTempFile("gomate-probe-",".log");
  Process p=null;
  try {
   p=new ProcessBuilder(command).redirectError(ProcessBuilder.Redirect.DISCARD).redirectOutput(output.toFile()).start();
   if(!p.waitFor(seconds,TimeUnit.SECONDS)) {p.destroyForcibly();throw new IllegalStateException("Media process timeout");}
   if(p.exitValue()!=0 || Files.size(output)>1000000) throw new IllegalStateException("Invalid media");
   return Files.readAllBytes(output);
  } finally {if(p!=null && p.isAlive()) p.destroyForcibly();Files.deleteIfExists(output);}
 }
}
