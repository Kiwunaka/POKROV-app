enum ProblemBookAvailability { supported, notShipped }

final class OperationalProblemBookEntry {
  OperationalProblemBookEntry({
    required this.id,
    required this.availability,
    required List<String> errorCodes,
    required List<String> observedEvents,
    required List<String> notObservedEvents,
    required List<String> safeActions,
  })  : errorCodes = List.unmodifiable(errorCodes),
        observedEvents = List.unmodifiable(observedEvents),
        notObservedEvents = List.unmodifiable(notObservedEvents),
        safeActions = List.unmodifiable(safeActions) {
    if (!RegExp(r'^PB-(?:0[1-9]|1[0-4])$').hasMatch(id)) {
      throw ArgumentError.value(id, 'id');
    }
    if (availability == ProblemBookAvailability.supported &&
        (observedEvents.isEmpty ||
            notObservedEvents.isEmpty ||
            safeActions.isEmpty)) {
      throw ArgumentError('Supported problem-book entries require evidence');
    }
  }

  final String id;
  final ProblemBookAvailability availability;
  final List<String> errorCodes;
  final List<String> observedEvents;
  final List<String> notObservedEvents;
  final List<String> safeActions;
}

abstract final class OperationalProblemBook {
  static final List<OperationalProblemBookEntry> entries =
      <OperationalProblemBookEntry>[
    _entry(
      'PB-01',
      codes: <String>['APP-BOOT-002', 'APP-BOOT-004', 'APP-BOOT-005'],
      observed: <String>[
        'app.previous_exit.detected',
        'app.bootstrap.initialize.started'
      ],
      missing: <String>[
        'app.bootstrap.initialize.finished',
        'app.bootstrap.ui_ready.finished'
      ],
      actions: <String>['repair_release', 'retry_safe_start', 'send_bundle'],
    ),
    _entry(
      'PB-02',
      codes: <String>[
        'API-001',
        'API-002',
        'API-003',
        'AUTH-002',
        'AUTH-004',
        'AUTH-005'
      ],
      observed: <String>['app.auth.request.started'],
      missing: <String>['app.auth.request.finished'],
      actions: <String>[
        'check_system_time',
        'reauthenticate',
        'contact_support'
      ],
    ),
    _entry(
      'PB-03',
      codes: <String>['CONN-001', 'CONN-007', 'CONN-008'],
      observed: <String>['app.connection.intent.received'],
      missing: <String>['app.connection.profile.started'],
      actions: <String>['complete_permission', 'retry_connect', 'send_bundle'],
    ),
    _entry(
      'PB-04',
      codes: <String>[
        'WIN-SVC-001',
        'WIN-SVC-002',
        'WIN-SVC-003',
        'WIN-SVC-004',
        'WIN-SVC-005'
      ],
      observed: <String>['windows_service.command.requested'],
      missing: <String>['windows_service.command.finished'],
      actions: <String>['repair_service', 'restart_service', 'send_bundle'],
    ),
    _entry(
      'PB-05',
      codes: <String>['TUN-004', 'DNS-002', 'EGRESS-001'],
      observed: <String>['app.connection.tun.finished'],
      missing: <String>['app.connection.verified.finished'],
      actions: <String>['retry_verification', 'rotate_node', 'send_bundle'],
    ),
    _entry(
      'PB-06',
      codes: <String>['TUN-003', 'ROUTE-003', 'ROUTE-004'],
      observed: <String>['app.connection.verified.finished'],
      missing: <String>['app.connection.routes.finished'],
      actions: <String>[
        'run_visible_route_test',
        'change_route_mode',
        'send_summary'
      ],
    ),
    _entry(
      'PB-07',
      codes: <String>['DNS-002', 'DNS-003', 'DNS-004'],
      observed: <String>['app.connection.dns.started'],
      missing: <String>[
        'app.connection.dns.finished',
        'app.connection.rollback.finished'
      ],
      actions: <String>['stop_connection', 'repair_dns', 'send_bundle'],
    ),
    _entry(
      'PB-08',
      codes: <String>['AND-BG-001', 'AND-BG-002', 'AND-BG-003', 'AND-VPN-004'],
      observed: <String>['android_host.lifecycle.stopped'],
      missing: <String>['app.connection.stopped.finished'],
      actions: <String>[
        'open_android_guidance',
        'retry_connect',
        'send_bundle'
      ],
    ),
    OperationalProblemBookEntry(
      id: 'PB-09',
      availability: ProblemBookAvailability.notShipped,
      errorCodes: const <String>[],
      observedEvents: const <String>[],
      notObservedEvents: const <String>[],
      safeActions: const <String>['state_linux_not_shipped'],
    ),
    _entry(
      'PB-10',
      codes: <String>['PERF-001', 'TUN-004'],
      observed: <String>['app.connection.verified.finished'],
      missing: <String>['app.performance.sample.finished'],
      actions: <String>[
        'run_visible_speed_test',
        'change_node',
        'send_summary'
      ],
    ),
    _entry(
      'PB-11',
      codes: <String>[
        'UPD-001',
        'UPD-002',
        'UPD-003',
        'UPD-004',
        'UPD-005',
        'UPD-006',
        'UPD-007'
      ],
      observed: <String>['app.update.install.started'],
      missing: <String>['app.update.install.finished'],
      actions: <String>[
        'retry_update',
        'use_official_channel',
        'contact_support'
      ],
    ),
    _entry(
      'PB-12',
      codes: <String>['ENT-001', 'ENT-003', 'API-007'],
      observed: <String>['app.entitlement.refresh.started'],
      missing: <String>['app.entitlement.refresh.finished'],
      actions: <String>[
        'refresh_access',
        'wait_for_processing',
        'contact_support'
      ],
    ),
    _entry(
      'PB-13',
      codes: <String>[
        'SUP-001',
        'SUP-002',
        'SUP-003',
        'SUP-004',
        'SUP-005',
        'SUP-006'
      ],
      observed: <String>['app.support.bundle.started'],
      missing: <String>['app.support.bundle.finished'],
      actions: <String>[
        'export_encrypted_bundle',
        'send_summary_code',
        'retry_upload'
      ],
    ),
    _entry(
      'PB-14',
      codes: <String>['CRASH-001', 'CRASH-002', 'CRASH-003', 'UPD-006'],
      observed: <String>['app.previous_exit.detected'],
      missing: <String>['app.bootstrap.ui_ready.finished'],
      actions: <String>[
        'pause_promotion',
        'publish_known_issue',
        'rollback_release'
      ],
    ),
  ];

  static OperationalProblemBookEntry byId(String id) =>
      entries.singleWhere((entry) => entry.id == id);

  static OperationalProblemBookEntry _entry(
    String id, {
    required List<String> codes,
    required List<String> observed,
    required List<String> missing,
    required List<String> actions,
  }) =>
      OperationalProblemBookEntry(
        id: id,
        availability: ProblemBookAvailability.supported,
        errorCodes: codes,
        observedEvents: observed,
        notObservedEvents: missing,
        safeActions: actions,
      );
}
