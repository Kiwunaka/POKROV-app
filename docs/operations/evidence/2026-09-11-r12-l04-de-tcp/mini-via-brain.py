import pathlib,subprocess,sys
script=pathlib.Path(sys.argv[1]).read_text(encoding='utf-8')
raise SystemExit(subprocess.run(['ssh','-J','pokrov-brain','-o','BatchMode=yes','-o','StrictHostKeyChecking=yes','pokrov-mini','sudo -n python3 -' if '--sudo' in sys.argv[2:] else 'python3 -'],input=script,text=True).returncode)
