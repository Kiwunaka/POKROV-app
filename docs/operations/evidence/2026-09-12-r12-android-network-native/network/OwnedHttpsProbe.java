import java.net.*;
import javax.net.ssl.HttpsURLConnection;
public final class OwnedHttpsProbe {
 public static void main(String[] args) throws Exception {
  int count=Integer.parseInt(args[0]);if(count<1||count>10)throw new IllegalArgumentException();
  System.out.print("{\"requests\":[");
  for(int i=0;i<count;i++){
   if(i>0)System.out.print(",");long started=System.nanoTime();int status=0;boolean marker=false;String error="";
   HttpsURLConnection c=null;
   try{c=(HttpsURLConnection)new URL("https://api.pokrov.space/api/public/authenticated-egress-probe").openConnection();c.setConnectTimeout(12000);c.setReadTimeout(12000);c.setInstanceFollowRedirects(false);c.setRequestProperty("Connection","close");status=c.getResponseCode();marker="pokrov-authenticated-egress-v1".equals(c.getHeaderField("x-pokrov-egress-probe"));}
   catch(Exception e){error=e.getClass().getSimpleName();}finally{if(c!=null)c.disconnect();}
   System.out.print("{\"status\":"+status+",\"marker_valid\":"+marker+",\"error_type\":\""+error+"\",\"elapsed_ms\":"+((System.nanoTime()-started)/1000000)+"}");
  }
  System.out.println("]}");
 }
}
