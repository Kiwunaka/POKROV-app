from pathlib import Path
import subprocess
out=Path('E:/r12-huawei-current-20260910');sdk=Path('E:/POKROV-workspace-cache/android-sdk');android=sdk/'platforms/android-31/android.jar'
subprocess.run(['C:/Users/kiwun/tools/jdk/17.0.18/bin/javac.exe','-source','8','-target','8','-classpath',str(android),str(out/'R12Http.java')],check=True)
subprocess.run([str(sdk/'build-tools/34.0.0/d8.bat'),'--min-api','24','--lib',str(android),'--output',str(out/'r12-http.jar'),str(out/'R12Http.class')],check=True)
subprocess.run([str(sdk/'platform-tools/adb.exe'),'-s','2UCUT24716017005','push',str(out/'r12-http.jar'),'/data/local/tmp/r12-http.jar'],check=True)
