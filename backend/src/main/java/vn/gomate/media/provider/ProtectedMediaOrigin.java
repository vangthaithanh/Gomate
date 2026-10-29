package vn.gomate.media.provider;

import java.io.*;
import java.net.*;
import org.springframework.stereotype.Component;

/** The signed Cloudinary URL and connection never cross the Spring boundary. */
@Component
public class ProtectedMediaOrigin {
 public record Body(InputStream stream,long total,long offset,AutoCloseable connection) implements AutoCloseable {
  @Override public void close() throws Exception {try{stream.close();}finally{connection.close();}}
 }
 public Body open(String signed,String range) throws Exception {
  var uri=URI.create(signed);
  if(!"https".equals(uri.getScheme()) || !"api.cloudinary.com".equals(uri.getHost())) throw new IOException("Unexpected origin");
  var connection=(HttpURLConnection)uri.toURL().openConnection();
  connection.setInstanceFollowRedirects(false);connection.setConnectTimeout(5000);connection.setReadTimeout(20000);
  if(range!=null && range.matches("bytes=\\d*-\\d*")) connection.setRequestProperty("Range",range);
  try {
   int code=connection.getResponseCode();long total=connection.getContentLengthLong(),offset=0;
   if(code==416 && range!=null) {
    connection.disconnect();
    // Recover the true length so Spring can return its own controlled 416.
    return open(signed,null);
   }
   if(code==206) {
    var match=java.util.regex.Pattern.compile("bytes (\\d+)-(\\d+)/(\\d+)").matcher(connection.getHeaderField("Content-Range"));
    if(!match.matches()) throw new IOException("Invalid origin range");
    offset=Long.parseLong(match.group(1));total=Long.parseLong(match.group(3));
   } else if(code!=200) throw new IOException("Protected origin unavailable");
   if(total<=0) throw new IOException("Missing content length");
   return new Body(connection.getInputStream(),total,offset,connection::disconnect);
  } catch(Exception e) {connection.disconnect();throw new IOException("Protected origin unavailable");}
 }
}
