import java.net.HttpURLConnection;
import java.net.URL;
import java.io.InputStream;
import java.security.MessageDigest;
public class R12Http {
 public static void main(String[] args) {
  long start=System.nanoTime();
  HttpURLConnection c=null;
  try {
   c=(HttpURLConnection)new URL("https://pokrov.space/__build.json").openConnection();
   c.setConnectTimeout(5000);c.setReadTimeout(5000);c.setUseCaches(false);c.setInstanceFollowRedirects(false);
   int status=c.getResponseCode();MessageDigest digest=MessageDigest.getInstance("SHA-256");int size=0;
   if(status==200)try(InputStream in=c.getInputStream()) {byte[] b=new byte[4096];int n;while((n=in.read(b))!=-1) {size+=n;if(size>1048576)throw new IllegalStateException("oversized");digest.update(b,0,n);}}
   StringBuilder hex=new StringBuilder();for(byte b:digest.digest())hex.append(String.format("%02x",b));
   System.out.println("{\"status\":\"HTTP_RESPONSE\",\"http_status\":"+status+",\"bytes\":"+size+",\"sha256\":\""+hex+"\",\"elapsed_ms\":"+((System.nanoTime()-start)/1000000)+"}");
  } catch(Exception e) {System.out.println("{\"status\":\"NETWORK_FAILED\",\"exception_class\":\""+e.getClass().getSimpleName()+"\",\"elapsed_ms\":"+((System.nanoTime()-start)/1000000)+"}");}
  finally {if(c!=null)c.disconnect();}
 }
}
