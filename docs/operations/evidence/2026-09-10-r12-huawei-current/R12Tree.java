import android.app.UiAutomation;
import android.graphics.Rect;
import android.util.Xml;
import android.view.accessibility.AccessibilityNodeInfo;
import com.android.uiautomator.testrunner.UiAutomatorTestCase;
import java.io.StringWriter;
import org.xmlpull.v1.XmlSerializer;
public class R12Tree extends UiAutomatorTestCase {
  private void node(XmlSerializer xml, AccessibilityNodeInfo n) throws Exception {
    xml.startTag(null,"node");
    xml.attribute(null,"text",n.getText()==null?"":n.getText().toString());
    xml.attribute(null,"content-desc",n.getContentDescription()==null?"":n.getContentDescription().toString());
    xml.attribute(null,"package",n.getPackageName()==null?"":n.getPackageName().toString());
    xml.attribute(null,"class",n.getClassName()==null?"":n.getClassName().toString());
    xml.attribute(null,"clickable",String.valueOf(n.isClickable()));
    xml.attribute(null,"scrollable",String.valueOf(n.isScrollable()));
    Rect b=new Rect();n.getBoundsInScreen(b);
    xml.attribute(null,"bounds","["+b.left+","+b.top+"]["+b.right+","+b.bottom+"]");
    for(int i=0;i<n.getChildCount();i++) {AccessibilityNodeInfo c=n.getChild(i);if(c!=null){node(xml,c);c.recycle();}}
    xml.endTag(null,"node");
  }
  public void testTree() throws Exception {
    Object d=getUiDevice();
    java.lang.reflect.Method gm=d.getClass().getDeclaredMethod("getAutomatorBridge");gm.setAccessible(true);
    Object bridge=gm.invoke(d);
    java.lang.reflect.Field f=bridge.getClass().getSuperclass().getDeclaredField("mUiAutomation");f.setAccessible(true);
    UiAutomation automation=(UiAutomation)f.get(bridge);
    sleep(750);
    AccessibilityNodeInfo root=automation.getRootInActiveWindow();
    assertNotNull("active window root",root);
    StringWriter output=new StringWriter();XmlSerializer xml=Xml.newSerializer();xml.setOutput(output);
    xml.startDocument("UTF-8",true);xml.startTag(null,"hierarchy");node(xml,root);xml.endTag(null,"hierarchy");xml.endDocument();
    System.out.println(output.toString());root.recycle();
  }
}
