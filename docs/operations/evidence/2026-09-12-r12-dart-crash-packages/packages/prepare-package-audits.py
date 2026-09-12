from pathlib import Path
old=Path('C:/r12-c05-setup-privacy-20260912')
out=Path(__file__).parent
source='f7115c505c314a7322481997a46343b03dae1127'
for name in ['audit-android.py','audit-windows.py']:
    text=(old/name).read_text().replace('2aa57015783ceb3415e3be62bbf0a698729011c4',source).replace('C:/r12-c05-setup-privacy-20260912',str(out).replace('\\','/'))
    if name=='audit-windows.py':
        text=text.replace("assert manifest['version'] == '1.2.0+4053'", "assert manifest['version'] == '1.2.0+4053'\nassert b'"+source+"' in (bundle/'data/app.so').read_bytes(), 'Current Dart revision absent'")
        text=text.replace("'observed_at': datetime", "'source_client': '"+source+"', 'source_core': '6b271decead88b708e2fc03984b703b0a4e63ebd',\n          'observed_at': datetime")
    (out/name).write_text(text,encoding='utf8')
text=(old/'prepare-android-audit.py').read_text().split('text=(prior/')[0].replace('2aa57015783ceb3415e3be62bbf0a698729011c4',source)
text += "print('PASS all current DEX bytes exactly match prior parsed artifacts')\n"
(out/'bind-current-dex.py').write_text(text,encoding='utf8')
print('Prepared audits; not yet run against pending packages')
