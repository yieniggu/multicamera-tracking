import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/features/auth/presentation/screens/migration_conflict_screen.dart';
import 'package:multicamera_tracking/l10n/app_localizations.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester,
    GuestMigrationPreview preview, {
    List<String> initialValidationIssues = const [],
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () {
                    showMigrationConflictScreen(
                      context: context,
                      preview: preview,
                      initialValidationIssues: initialValidationIssues,
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('validation issues card supports arrows and swipe', (
    tester,
  ) async {
    const preview = GuestMigrationPreview(
      projectConflicts: [
        ProjectConflictPreview(
          localProjectId: 'local-1',
          localName: 'Project',
          localDescription: 'local',
          remoteOptions: [
            RemoteProjectOption(
              id: 'remote-1',
              name: 'Project',
              description: 'remote',
            ),
          ],
        ),
      ],
      sourceProjectCount: 1,
      targetProjectCount: 1,
    );

    await pumpHost(
      tester,
      preview,
      initialValidationIssues: const ['Issue A', 'Issue B'],
    );

    expect(
      find.byKey(const Key('migration_issue_count_badge')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('migration_issue_position')), findsOneWidget);
    expect(
      (tester.widget(find.byKey(const Key('migration_issue_position'))) as Text)
          .data,
      '1/2',
    );
    expect(find.byKey(const Key('migration_issue_prev')), findsOneWidget);
    expect(find.byKey(const Key('migration_issue_next')), findsOneWidget);

    await tester.tap(find.byKey(const Key('migration_issue_next')));
    await tester.pumpAndSettle();

    expect(
      (tester.widget(find.byKey(const Key('migration_issue_position'))) as Text)
          .data,
      '2/2',
    );
    expect(find.byKey(const Key('migration_issue_swipe_area')), findsOneWidget);
    await tester.tap(find.byKey(const Key('migration_issue_prev')));
    await tester.pumpAndSettle();

    expect(
      (tester.widget(find.byKey(const Key('migration_issue_position'))) as Text)
          .data,
      '1/2',
    );
  });

  testWidgets(
    'does not offer create-new project option when same-name remote project exists',
    (tester) async {
      const preview = GuestMigrationPreview(
        projectConflicts: [
          ProjectConflictPreview(
            localProjectId: 'local-1',
            localName: 'My Project',
            localDescription: 'local',
            remoteOptions: [
              RemoteProjectOption(
                id: 'remote-1',
                name: 'My Project',
                description: 'remote',
              ),
            ],
          ),
        ],
        sourceProjectCount: 1,
        targetProjectCount: 1,
      );

      await pumpHost(tester, preview);

      expect(find.text('Target remote project'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
      await tester.pumpAndSettle();

      expect(find.text('Create new in remote'), findsNothing);
      expect(find.text('My Project').last, findsOneWidget);
    },
  );

  testWidgets('skips group and camera steps when project target is create-new', (
    tester,
  ) async {
    const preview = GuestMigrationPreview(
      projectConflicts: [
        ProjectConflictPreview(
          localProjectId: 'local-1',
          localName: 'Local Project',
          localDescription: 'local',
          remoteOptions: [
            RemoteProjectOption(
              id: 'remote-1',
              name: 'Different Remote',
              description: 'remote',
            ),
          ],
          groupConflicts: [
            GroupConflictPreview(
              localGroupId: 'group-1',
              localName: 'Group A',
              localDescription: 'group',
              cameraConflicts: [
                CameraConflictPreview(
                  localCameraId: 'camera-1',
                  localName: 'Camera A',
                  localDescription: 'camera',
                ),
              ],
            ),
          ],
        ),
      ],
      sourceProjectCount: 1,
      targetProjectCount: 1,
    );

    await pumpHost(tester, preview);

    // Different names => create-new is selected by default, so no deeper steps.
    expect(find.text('Next'), findsNothing);
    expect(find.text('Migrate'), findsOneWidget);
    expect(find.text('Migrate anyway'), findsNothing);
    expect(find.text('Step 2: Groups'), findsNothing);
    expect(find.text('Step 3: Cameras'), findsNothing);
  });

  testWidgets('overwrite strategy does not offer create-new target project', (
    tester,
  ) async {
    const preview = GuestMigrationPreview(
      projectConflicts: [
        ProjectConflictPreview(
          localProjectId: 'local-1',
          localName: 'Local Project',
          localDescription: 'local',
          remoteOptions: [
            RemoteProjectOption(
              id: 'remote-1',
              name: 'Different Remote',
              description: 'remote',
            ),
          ],
        ),
      ],
      sourceProjectCount: 1,
      targetProjectCount: 1,
    );

    await pumpHost(tester, preview);

    await tester.tap(find.text('Merge').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Overwrite').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await tester.pumpAndSettle();

    expect(find.text('Create new in remote'), findsNothing);
    expect(find.text('Different Remote').last, findsOneWidget);
  });

  testWidgets(
    'merge strategy hides create-new when same-name remote group exists',
    (tester) async {
      const preview = GuestMigrationPreview(
        projectConflicts: [
          ProjectConflictPreview(
            localProjectId: 'local-1',
            localName: 'Shared Project',
            localDescription: 'local',
            remoteOptions: [
              RemoteProjectOption(
                id: 'remote-1',
                name: 'Shared Project',
                description: 'remote',
                groups: [
                  RemoteGroupOption(
                    id: 'remote-group-1',
                    name: 'Shared Group',
                    description: 'remote-group',
                  ),
                ],
              ),
            ],
            groupConflicts: [
              GroupConflictPreview(
                localGroupId: 'local-group-1',
                localName: 'Shared Group',
                localDescription: 'local-group',
              ),
            ],
          ),
        ],
        sourceProjectCount: 1,
        targetProjectCount: 1,
      );

      await pumpHost(tester, preview);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_drop_down).last);
      await tester.pumpAndSettle();

      expect(find.text('Create new in remote'), findsNothing);
      expect(find.text('Shared Group').last, findsOneWidget);
    },
  );

  testWidgets(
    'project overwrite locks target selector to same-name remote project',
    (tester) async {
      const preview = GuestMigrationPreview(
        projectConflicts: [
          ProjectConflictPreview(
            localProjectId: 'local-1',
            localName: 'Shared Project',
            localDescription: 'local',
            remoteOptions: [
              RemoteProjectOption(
                id: 'remote-1',
                name: 'Shared Project',
                description: 'remote',
              ),
              RemoteProjectOption(
                id: 'remote-2',
                name: 'Other Project',
                description: 'remote',
              ),
            ],
          ),
        ],
        sourceProjectCount: 1,
        targetProjectCount: 2,
      );

      await pumpHost(tester, preview);

      await tester.tap(find.text('Merge').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overwrite').last);
      await tester.pumpAndSettle();

      final targetSelector = tester.widget<DropdownButtonFormField<String?>>(
        find.byType(DropdownButtonFormField<String?>).first,
      );
      expect(targetSelector.onChanged, isNull);
    },
  );

  testWidgets(
    'group overwrite locks target selector to same-name remote group',
    (tester) async {
      const preview = GuestMigrationPreview(
        projectConflicts: [
          ProjectConflictPreview(
            localProjectId: 'local-1',
            localName: 'Shared Project',
            localDescription: 'local',
            remoteOptions: [
              RemoteProjectOption(
                id: 'remote-1',
                name: 'Shared Project',
                description: 'remote',
                groups: [
                  RemoteGroupOption(
                    id: 'remote-group-1',
                    name: 'Shared Group',
                    description: 'remote-group',
                  ),
                  RemoteGroupOption(
                    id: 'remote-group-2',
                    name: 'Other Group',
                    description: 'remote-group',
                  ),
                ],
              ),
            ],
            groupConflicts: [
              GroupConflictPreview(
                localGroupId: 'local-group-1',
                localName: 'Shared Group',
                localDescription: 'local-group',
              ),
            ],
          ),
        ],
        sourceProjectCount: 1,
        targetProjectCount: 1,
      );

      await pumpHost(tester, preview);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Merge').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overwrite').last);
      await tester.pumpAndSettle();

      final groupTargetSelector = tester
          .widget<DropdownButtonFormField<String?>>(
            find.byType(DropdownButtonFormField<String?>).first,
          );
      expect(groupTargetSelector.onChanged, isNull);
    },
  );

  testWidgets(
    'group overwrite removes camera step when no merge groups remain',
    (tester) async {
      const preview = GuestMigrationPreview(
        projectConflicts: [
          ProjectConflictPreview(
            localProjectId: 'local-1',
            localName: 'Shared Project',
            localDescription: 'local',
            remoteOptions: [
              RemoteProjectOption(
                id: 'remote-1',
                name: 'Shared Project',
                description: 'remote',
                groups: [
                  RemoteGroupOption(
                    id: 'remote-group-1',
                    name: 'Shared Group',
                    description: 'remote-group',
                    cameras: [
                      RemoteCameraOption(
                        id: 'remote-camera-1',
                        name: 'Camera A',
                        description: 'remote-camera',
                      ),
                    ],
                  ),
                ],
              ),
            ],
            groupConflicts: [
              GroupConflictPreview(
                localGroupId: 'local-group-1',
                localName: 'Shared Group',
                localDescription: 'local-group',
                cameraConflicts: [
                  CameraConflictPreview(
                    localCameraId: 'local-camera-1',
                    localName: 'Camera A',
                    localDescription: 'local-camera',
                  ),
                ],
              ),
            ],
          ),
        ],
        sourceProjectCount: 1,
        targetProjectCount: 1,
      );

      await pumpHost(tester, preview);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Merge').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overwrite').last);
      await tester.pumpAndSettle();

      expect(find.text('Next'), findsNothing);
      expect(find.text('Migrate'), findsOneWidget);
      expect(find.text('Step 3: Cameras'), findsNothing);
    },
  );

  testWidgets(
    'shows validation issues and blocks submit for invalid mappings',
    (tester) async {
      const remoteProject = RemoteProjectOption(
        id: 'remote-1',
        name: 'Shared Project',
        description: 'remote',
        groups: [
          RemoteGroupOption(
            id: 'remote-group-1',
            name: 'Target Group',
            description: 'remote-group',
          ),
        ],
      );
      const preview = GuestMigrationPreview(
        projectConflicts: [
          ProjectConflictPreview(
            localProjectId: 'local-1',
            localName: 'Shared Project',
            localDescription: 'local-1',
            remoteOptions: [remoteProject],
            groupConflicts: [
              GroupConflictPreview(
                localGroupId: 'local-group-1',
                localName: 'Source Group A',
                localDescription: 'group-a',
              ),
            ],
          ),
          ProjectConflictPreview(
            localProjectId: 'local-2',
            localName: 'Shared Project',
            localDescription: 'local-2',
            remoteOptions: [remoteProject],
            groupConflicts: [
              GroupConflictPreview(
                localGroupId: 'local-group-2',
                localName: 'Source Group B',
                localDescription: 'group-b',
              ),
            ],
          ),
        ],
        sourceProjectCount: 2,
        targetProjectCount: 1,
      );

      await pumpHost(tester, preview);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      final strategies = find.byType(DropdownButtonFormField<MergeStrategy>);
      await tester.ensureVisible(strategies.first);
      await tester.tap(strategies.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overwrite').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(strategies.at(1));
      await tester.tap(strategies.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overwrite').last);
      await tester.pumpAndSettle();

      final migrateAction = find.text('Migrate').last;
      await tester.ensureVisible(migrateAction);
      await tester.tap(migrateAction);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('migration_issue_count_badge')),
        findsOneWidget,
      );
      expect(find.text('This account already has data'), findsOneWidget);
    },
  );

  testWidgets('camera with same-name remote only allows overwrite or skip', (
    tester,
  ) async {
    const preview = GuestMigrationPreview(
      projectConflicts: [
        ProjectConflictPreview(
          localProjectId: 'local-1',
          localName: 'Shared Project',
          localDescription: 'local',
          remoteOptions: [
            RemoteProjectOption(
              id: 'remote-1',
              name: 'Shared Project',
              description: 'remote',
              groups: [
                RemoteGroupOption(
                  id: 'remote-group-1',
                  name: 'Shared Group',
                  description: 'remote-group',
                  cameras: [
                    RemoteCameraOption(
                      id: 'remote-camera-1',
                      name: 'Camera A',
                      description: 'remote-camera',
                    ),
                  ],
                ),
              ],
            ),
          ],
          groupConflicts: [
            GroupConflictPreview(
              localGroupId: 'local-group-1',
              localName: 'Shared Group',
              localDescription: 'local-group',
              cameraConflicts: [
                CameraConflictPreview(
                  localCameraId: 'local-camera-1',
                  localName: 'Camera A',
                  localDescription: 'local-camera',
                ),
              ],
            ),
          ],
        ),
      ],
      sourceProjectCount: 1,
      targetProjectCount: 1,
    );

    await pumpHost(tester, preview);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await tester.pumpAndSettle();

    expect(find.text('Overwrite').last, findsOneWidget);
    expect(find.text('Skip').last, findsOneWidget);
    expect(find.text('Migrate'), findsOneWidget);
    expect(find.text('Merge'), findsNothing);
  });

  testWidgets('camera without same-name remote only allows migrate or skip', (
    tester,
  ) async {
    const preview = GuestMigrationPreview(
      projectConflicts: [
        ProjectConflictPreview(
          localProjectId: 'local-1',
          localName: 'Shared Project',
          localDescription: 'local',
          remoteOptions: [
            RemoteProjectOption(
              id: 'remote-1',
              name: 'Shared Project',
              description: 'remote',
              groups: [
                RemoteGroupOption(
                  id: 'remote-group-1',
                  name: 'Shared Group',
                  description: 'remote-group',
                  cameras: [
                    RemoteCameraOption(
                      id: 'remote-camera-1',
                      name: 'Different Camera',
                      description: 'remote-camera',
                    ),
                  ],
                ),
              ],
            ),
          ],
          groupConflicts: [
            GroupConflictPreview(
              localGroupId: 'local-group-1',
              localName: 'Shared Group',
              localDescription: 'local-group',
              cameraConflicts: [
                CameraConflictPreview(
                  localCameraId: 'local-camera-1',
                  localName: 'Camera A',
                  localDescription: 'local-camera',
                ),
              ],
            ),
          ],
        ),
      ],
      sourceProjectCount: 1,
      targetProjectCount: 1,
    );

    await pumpHost(tester, preview);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_drop_down).first);
    await tester.pumpAndSettle();

    expect(find.text('Migrate').last, findsOneWidget);
    expect(find.text('Skip').last, findsOneWidget);
    expect(find.text('Overwrite'), findsNothing);
    expect(find.text('Merge'), findsNothing);
  });
}
