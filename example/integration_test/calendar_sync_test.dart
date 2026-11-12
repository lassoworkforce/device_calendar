import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// LMA-2925: a calendar the plugin creates must be created with the provider's
/// `sync_events` flag on, and the Events table must be readable without Instances.
///
/// Android only. Run on an emulator:
///   cd example && flutter test integration_test/calendar_sync_test.dart -d emulator-5554
/// Grant calendar permission first:
///   adb shell pm grant com.builttoroam.devicecalendarexample android.permission.READ_CALENDAR
///   adb shell pm grant com.builttoroam.devicecalendarexample android.permission.WRITE_CALENDAR
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'a created calendar has sync_events on and its event ids read back',
      (tester) async {
    final plugin = DeviceCalendarPlugin();
    final permissions = await plugin.requestPermissions();
    expect(permissions.data, true);

    final created = await plugin.createCalendar('LMA-2925 probe',
        localAccountName: 'LMA-2925 probe');
    final calendarId = created.data!;
    try {
      final calendars = (await plugin.retrieveCalendars()).data!;
      final probe = calendars.firstWhere((c) => c.id == calendarId);
      expect(probe.syncEvents, true,
          reason: 'createCalendar must set sync_events=1');

      final start = TZDateTime.now(UTC).add(const Duration(days: 1));
      final expected = <String>{};
      for (final title in ['one', 'two']) {
        final event = Event(calendarId,
            title: title,
            start: start,
            end: start.add(const Duration(hours: 1)));
        final saved = await plugin.createOrUpdateEvent(event);
        expected.add(saved!.data!);
      }

      final ids = (await plugin.retrieveEventIds(calendarId)).data!;
      expect(ids.toSet(), expected);

      // enableCalendarSync updates the row (the app calls it on calendars at 0).
      final enabled = await plugin.enableCalendarSync(calendarId);
      expect(enabled.data, true);
    } finally {
      await plugin.deleteCalendar(calendarId);
    }
  });
}
