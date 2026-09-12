"""Scan only the owned native case, with normal HTTPS access audit; export no content."""
import base64, datetime as dt, hashlib, json, logging, os, pathlib, sys, urllib.error, urllib.parse, urllib.request
logging.disable(logging.CRITICAL)
from dotenv import load_dotenv
load_dotenv('/root/portal_bot/.env'); sys.path.insert(0, '/root/portal_bot')
from db import SessionLocal
from models import AdminOperator, AdminOperatorSession, SupportBundleUpload, SupportBundleAccessAudit, SupportTicket, User
from admin_v2.security import ADMIN_SESSION_COOKIE, OperatorSessionConfig, _issue_session_for_operator, mark_operator_step_up
from support_bundle_ingest_service import parse_encrypted_envelope, validate_decrypted_payload
from support_bundle_worker import load_mounted_support_decryptor

CASE = 58
SOURCE = '25c6f7a13a04ee41fa6a86b84fbf90e045580a2f'
CIPHER_SHA = '65136a5583657a3e2b9b77ab526e1b614cfcce0dae575ff06bb185265d76df3d'
assert os.environ['PORTAL_BUILD_COMMIT'] == SOURCE
state = json.loads(pathlib.Path('/root/portal-r12-evidence/support-enable-20260910/runtime-case-state-v2.json').read_bytes())
issued = None; before = {}; upload_id = None
report = {'status': 'UNCONFIRMED', 'case_number': CASE, 'origin': 'brain-origin real HTTPS and worker-key in-memory scan', 'source_revision': SOURCE, 'external_oidc_retested': False, 'planted_native_to_app_canaries_exercised': False, 'plaintext_or_credentials_exported': False}
def now(): return dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)
def contains_canary(raw): return any(marker in raw for marker in (b'r126b-20260912', b'203.0.113.198'))
def guard(s):
    ticket = s.get(SupportTicket, CASE)
    assert ticket and ticket.created_at >= dt.datetime(2026, 9, 12, 4, 23)
    user = s.query(User).filter(User.tg_id == ticket.user_tg_id).one()
    assert user.is_app_user and user.account_id == ticket.account_id
    assert hashlib.sha256(str(user.app_install_id).encode()).hexdigest() == 'a8e19d7739f511e191aba5d7bdef9162fc2f91c0709a5d34f516313a7ed8f557'
    row = s.query(SupportBundleUpload).filter(SupportBundleUpload.ticket_id == CASE, SupportBundleUpload.expected_sha256 == CIPHER_SHA).one()
    assert row.status == 'validated' and row.expected_sha256 == CIPHER_SHA and row.diagnostic_profile == 'summary'
    return ticket, row
def request(method, path, body=None, extra=None):
    headers = {'Cookie': ADMIN_SESSION_COOKIE + '=' + issued.token, 'Origin': 'https://admin.pokrov.space', 'X-Pokrov-Admin-CSRF': issued.context.csrf_token}
    raw = None
    if body is not None: raw = json.dumps(body).encode(); headers['Content-Type'] = 'application/json'
    if extra: headers.update(extra)
    req = urllib.request.Request('https://api.pokrov.space/api/admin/v2' + path, data=raw, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=20) as response: return response.status, response.read(), dict(response.headers)
    except urllib.error.HTTPError as error: return error.code, error.read(), dict(error.headers)
def read(path):
    code, raw, _ = request('GET', path); assert code == 200
    assert not contains_canary(raw)
    return json.loads(raw)['data']
try:
    cfg = OperatorSessionConfig.from_env(); cfg.validate(); assert cfg.environment == 'production'
    with SessionLocal() as s:
        _, row = guard(s); upload_id = row.upload_id; diagnostic_id = row.bundle_id
        audit_before = s.query(SupportBundleAccessAudit).filter(SupportBundleAccessAudit.ticket_id == CASE).count()
        op = s.query(AdminOperator).filter(AdminOperator.legacy_actor_tg_id == state['owner_tg_id'], AdminOperator.status == 'active').one()
        assert op.identity_source == 'telegram_oidc'
        before = {r.id: (r.revoked_at, r.revoke_reason) for r in s.query(AdminOperatorSession).filter(AdminOperatorSession.operator_id == op.id, AdminOperatorSession.revoked_at.is_(None)).all()}
        assert len(before) < cfg.max_active_sessions
        issued = _issue_session_for_operator(s, config=cfg, operator=op, roles=('superadmin',), trace_id=None, audit_action='session.r12_native_canary_fixture', audit_reason='owned_native_bundle_privacy_acceptance'); s.commit()
    lookups = []
    for kind, query in [('case_number', '#' + str(CASE)), ('diagnostic_id', diagnostic_id)]:
        results = read('/support/search?' + urllib.parse.urlencode({'q': query}))['results']
        own = [r for r in results if r['href'].split('&')[0] == '/tickets?selected=' + str(CASE)]
        assert own
        lookups.append({'kind': kind, 'own_result_count': len(own), 'canary_matches': 0})
    detail = read('/support/tickets/' + str(CASE)); bundles = [b for b in detail['support_bundles'] if b['diagnostic_profile'] == 'summary']; assert len(bundles) == 1
    bundle = bundles[0]; assert bundle['status'] == 'validated' and bundle['diagnostic_profile'] == 'summary'
    report['lookups'] = lookups
    report['operator_summary'] = {k: bundle.get(k) for k in ['diagnostic_profile', 'app_version', 'build_number', 'platform', 'architecture', 'last_phase', 'last_error_code', 'proof_outcome', 'attempt_link_source']}
    base = '/support/tickets/' + str(CASE) + '/bundles/' + bundle['bundle_ref']
    code, raw, _ = request('POST', base + '/access-grants', {'reason_code': 'customer_case'})
    assert code == 403 and json.loads(raw)['error']['code'] == 'operator_step_up_required'
    mark_operator_step_up(SessionLocal, context=issued.context, trace_id=None, method='r12_controlled_native_canary_fixture')
    code, raw, _ = request('POST', base + '/access-grants', {'reason_code': 'customer_case'}); assert code == 200
    grant = json.loads(raw)['data']
    code, encrypted, headers = request('GET', base + '/content', extra={'X-Pokrov-Support-Grant': grant['access_grant']})
    assert code == 200 and hashlib.sha256(encrypted).hexdigest() == CIPHER_SHA and headers.get('Cache-Control') == 'no-store'
    code, raw, _ = request('GET', base + '/content', extra={'X-Pokrov-Support-Grant': grant['access_grant']})
    assert code == 403 and json.loads(raw)['error']['code'] == 'support_bundle_access_grant_invalid'
    # Use the worker's existing root-only mount, never the API process or a copied key.
    key_path = pathlib.Path('/etc/pokrov/support-worker/recipients.json')
    assert key_path.stat().st_uid == 0 and key_path.stat().st_mode & 0o777 == 0o600
    envelope = parse_encrypted_envelope(encrypted)
    plaintext = load_mounted_support_decryptor(key_path)(envelope)
    payload = validate_decrypted_payload(plaintext, envelope=envelope)
    assert not contains_canary(plaintext)
    files = []
    for item in payload['files']:
        encoded = item['content_b64']
        content = base64.urlsafe_b64decode(encoded + '=' * ((4 - len(encoded) % 4) % 4))
        assert not contains_canary(content)
        if item['path'] == 'build/identity.json':
            ident = json.loads(content)
            report['build_identity'] = {k: ident.get(k) for k in ['app_version','build_number','platform','channel','candidate_label','git_revision','architecture']}
        files.append({'path': item['path'], 'bytes': len(content), 'sha256': hashlib.sha256(content).hexdigest(), 'canary_matches': 0})
    assert {f['path'] for f in files} == {'build/identity.json', 'network/summary.json', 'redaction/report.json'}
    report['payload_scan'] = {'profile': payload['manifest']['profile'], 'plaintext_bytes': len(plaintext), 'plaintext_sha256': hashlib.sha256(plaintext).hexdigest(), 'file_count': len(files), 'files': files, 'canary_matches': 0, 'extended_or_crash_included': False}
    with SessionLocal() as s:
        ticket, _ = guard(s)
        audits = s.query(SupportBundleAccessAudit).filter(SupportBundleAccessAudit.ticket_id == CASE).all()
        assert len(audits) > audit_before and any(a.used_at is not None for a in audits)
        report['access'] = {'without_step_up': 'DENIED', 'controlled_fixture_step_up': True, 'download': 'PASS_EXACT_CIPHERTEXT', 'replay': 'DENIED', 'cache_control': 'no-store', 'audit_rows_before': audit_before, 'audit_rows_after': len(audits), 'audit_actions': sorted({a.action for a in audits})}
        report['existing_case_status_preserved'] = ticket.status
    report['status'] = 'PASS_ANDROID_SUMMARY_ACCESS_SCAN'
except BaseException as error:
    report['status'] = 'FAIL_NATIVE_SUMMARY_SCAN'; report['failure_type'] = type(error).__name__
    tb = error.__traceback__
    while tb.tb_next: tb = tb.tb_next
    report['failure_line'] = tb.tb_lineno
finally:
    if issued:
        with SessionLocal() as s:
            row = s.get(AdminOperatorSession, issued.context.session_id); row.revoked_at = now(); row.revoke_reason = 'r12_native_canary_cleanup'; s.commit()
            report['session_cleanup'] = {'fixture_revoked': True, 'preexisting_unchanged': all((s.get(AdminOperatorSession, sid).revoked_at, s.get(AdminOperatorSession, sid).revoke_reason) == value for sid, value in before.items())}
    report['utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
    print(json.dumps(report))
sys.exit(0 if report['status'] == 'PASS_ANDROID_SUMMARY_ACCESS_SCAN' else 1)
