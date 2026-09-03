const TimePresenceManager = require('../src/managers/time_presence');

describe('TimePresenceManager', () => {
  jest.useFakeTimers('modern');

  afterAll(() => {
    jest.useRealTimers();
  });

  test('startSession and immediate state', () => {
    const manager = new TimePresenceManager({ shortAwayMinutes: 5, longAwayMinutes: 120, sessionTimeoutMinutes: 1440 });
    const now = new Date('2026-01-01T00:00:00Z');
    jest.setSystemTime(now);

    manager.startSession('s1');
    manager.touchUserMessage('s1');

    const state = manager.getState('s1');
    expect(state.sessionExists).toBe(true);
    expect(state.isShortAway).toBe(false);
    expect(state.isLongAway).toBe(false);
    expect(state.isTimedOut).toBe(false);
  });

  test('becomes short away after threshold', () => {
    const manager = new TimePresenceManager({ shortAwayMinutes: 5, longAwayMinutes: 120, sessionTimeoutMinutes: 1440 });
    const now = new Date('2026-01-01T00:00:00Z');
    jest.setSystemTime(now);

    manager.startSession('s2');
    manager.touchUserMessage('s2');

    // advance 10 minutes
    const later = new Date(now.getTime() + 10 * 60000);
    jest.setSystemTime(later);

    const state = manager.getState('s2');
    expect(state.isShortAway).toBe(true);
    expect(state.isLongAway).toBe(false);
  });

  test('becomes long away after threshold', () => {
    const manager = new TimePresenceManager({ shortAwayMinutes: 5, longAwayMinutes: 120, sessionTimeoutMinutes: 1440 });
    const now = new Date('2026-01-01T00:00:00Z');
    jest.setSystemTime(now);

    manager.startSession('s3');
    manager.touchUserMessage('s3');

    // advance 3 hours
    const later = new Date(now.getTime() + 3 * 60 * 60000);
    jest.setSystemTime(later);

    const state = manager.getState('s3');
    expect(state.isLongAway).toBe(true);
    expect(state.isTimedOut).toBe(false);
  });

  test('timed out after session timeout', () => {
    const manager = new TimePresenceManager({ shortAwayMinutes: 5, longAwayMinutes: 120, sessionTimeoutMinutes: 24 * 60 });
    const now = new Date('2026-01-01T00:00:00Z');
    jest.setSystemTime(now);

    manager.startSession('s4');
    manager.touchUserMessage('s4');

    // advance 2 days
    const later = new Date(now.getTime() + 2 * 24 * 60 * 60000);
    jest.setSystemTime(later);

    const state = manager.getState('s4');
    expect(state.isTimedOut).toBe(true);
  });
});
