import java.lang.reflect.*;
public final class CorePrivacyProbe {
  public static void main(String[] args) throws Exception {
    String[] markers={"R12_CREDENTIAL_2662", "R12_CONFIG_2662", "https://r12-url-2662.invalid/private", "198.51.100.126", "/r12-private-path-2662", "r12-person-2662@example.invalid"};
    Class<?> pcl=Class.forName("dalvik.system.PathClassLoader");
    ClassLoader loader=(ClassLoader)pcl.getConstructor(String.class,String.class,ClassLoader.class).newInstance(args[0],args[0]+"!/lib/x86_64",ClassLoader.getSystemClassLoader());
    Class<?> box=Class.forName("space.pokrov.core.libbox.Libbox",true,loader);
    Class<?> options=Class.forName("space.pokrov.core.libbox.SetupOptions",true,loader);
    Object setup=options.getConstructor().newInstance();
    for(String field:new String[]{"BasePath","WorkingPath","TempPath"}) options.getMethod("set"+field,String.class).invoke(setup,args[1]);
    options.getMethod("setDebug",boolean.class).invoke(setup,false);
    box.getMethod("setup",options).invoke(null,setup);
    String value=String.join("_",markers);
    String config="{\"outbounds\":[{\"type\":\""+value+"\"}]}";
    boolean rejected=false;String detail="";String failure="";
    try {box.getMethod("checkConfig",String.class).invoke(null,config);}
    catch(InvocationTargetException e){rejected=true;Throwable cause=e.getCause();detail=String.valueOf(cause.getMessage());failure=cause.getClass().getName();}
    int pid=(Integer)Class.forName("android.os.Process").getMethod("myPid").invoke(null);
    StringBuilder output=new StringBuilder("{\"check_config_invoked\":true,\"rejected\":"+rejected+",\"debug\":false,\"exception_type\":\""+failure+"\",\"exception_contains_markers\":[");
    for(int i=0;i<markers.length;i++){if(i>0)output.append(',');output.append(detail.contains(markers[i]));}
    output.append("],\"pid\":"+pid+",\"tunnel_started\":false,\"live_profile_used\":false}");
    System.out.println(output.toString());
    if(!rejected)System.exit(3);
  }
}
