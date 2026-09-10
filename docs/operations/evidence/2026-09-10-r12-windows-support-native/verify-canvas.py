from PIL import Image
from pathlib import Path
import json,hashlib
out=Path('E:/r12-windows-support-native-20260910')
r=[]
for name,expected in [('diagnostics.png',[0,0,0]),('fixed/diagnostics-light.png',[245,247,246]),('fixed/diagnostics-dark.png',[17,23,21])]:
 p=out/name;im=Image.open(p).convert('RGB');rgb=list(im.getpixel((700,400)));assert rgb==expected,(name,rgb)
 r.append({'screenshot':name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size':list(im.size),'canvas_sample':{'x':700,'y':400,'rgb':rgb}})
(out/'canvas-verification.json').write_text(json.dumps({'status':'PASS','method':'same native screen region sampled; screenshot visually inspected separately','before_light_canvas':'black','after_light_canvas':'theme light canvas','after_dark_canvas':'theme dark canvas','captures':r},indent=2)+'\n')
print('CANVAS_RGB_PASS')
