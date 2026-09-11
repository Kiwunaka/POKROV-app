import pathlib,os,json,subprocess
r=pathlib.Path('/tmp/pokrov-r12-l04-clean-20260911');base=pathlib.Path('/tmp/pokrov-r12-l02-20260911')
assert not pathlib.Path('/proc/1891755').exists() and not (r/'qemu.pid').exists()
args=json.loads((r/'start-args.json').read_text());assert '-no-reboot' in args;args.remove('-no-reboot')
assert ('file='+str(r/'guest.qcow2')+',if=virtio,format=qcow2') in args
args[args.index('-serial')+1]='file:'+str(r/'serial-reboot7.log');assert not (r/'serial-reboot7.log').exists()
p=subprocess.run(args,env={**os.environ,'LD_LIBRARY_PATH':str(base/'runtime/usr/lib/x86_64-linux-gnu')},capture_output=True,text=True);assert p.returncode==0,p.stderr[:500]
pid=int((r/'qemu.pid').read_text());assert pathlib.Path('/proc',str(pid)).exists()
receipt={'status':'RESTARTED_SAME_DISK_AFTER_GUEST_REBOOT','previous_pid':1891755,'pid':pid,'same_retained_disk':True,'original_no_reboot_flag':True,'no_reboot_flag_removed_for_subsequent_test':True,'previous_process_verified_absent':True}
(r/'candidate7-reboot-qemu.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
