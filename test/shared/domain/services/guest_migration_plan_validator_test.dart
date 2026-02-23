import 'package:flutter_test/flutter_test.dart';
import 'package:multicamera_tracking/shared/domain/entities/guest_migration.dart';
import 'package:multicamera_tracking/shared/domain/services/guest_migration_plan_validator.dart';

void main() {
  const remoteProject = RemoteProjectOption(
    id: 'rp1',
    name: 'Remote Project',
    description: 'remote',
    groups: [
      RemoteGroupOption(
        id: 'rg1',
        name: 'Target Group',
        description: 'remote-group',
      ),
    ],
  );

  const preview = GuestMigrationPreview(
    projectConflicts: [
      ProjectConflictPreview(
        localProjectId: 'lp1',
        localName: 'Local Project A',
        localDescription: 'local-a',
        remoteOptions: [remoteProject],
        groupConflicts: [
          GroupConflictPreview(
            localGroupId: 'lg1',
            localName: 'Source Group A',
            localDescription: 'group-a',
            cameraConflicts: [
              CameraConflictPreview(
                localCameraId: 'c1',
                localName: 'Shared Camera',
                localDescription: 'camera-a',
              ),
            ],
          ),
        ],
      ),
      ProjectConflictPreview(
        localProjectId: 'lp2',
        localName: 'Local Project B',
        localDescription: 'local-b',
        remoteOptions: [remoteProject],
        groupConflicts: [
          GroupConflictPreview(
            localGroupId: 'lg2',
            localName: 'Source Group B',
            localDescription: 'group-b',
            cameraConflicts: [
              CameraConflictPreview(
                localCameraId: 'c2',
                localName: 'Shared Camera',
                localDescription: 'camera-b',
              ),
            ],
          ),
        ],
      ),
    ],
    sourceProjectCount: 2,
    targetProjectCount: 1,
  );

  test('blocks multiple overwrite groups targeting same remote group', () {
    final plan = GuestMigrationPlan(
      projectResolutions: {
        'lp1': ProjectMergeResolution(
          localProjectId: 'lp1',
          strategy: MergeStrategy.merge,
          targetRemoteProjectId: 'rp1',
          groupResolutions: {
            'lg1': GroupMergeResolution(
              localGroupId: 'lg1',
              strategy: MergeStrategy.overwrite,
              targetRemoteGroupId: 'rg1',
            ),
          },
        ),
        'lp2': ProjectMergeResolution(
          localProjectId: 'lp2',
          strategy: MergeStrategy.merge,
          targetRemoteProjectId: 'rp1',
          groupResolutions: {
            'lg2': GroupMergeResolution(
              localGroupId: 'lg2',
              strategy: MergeStrategy.overwrite,
              targetRemoteGroupId: 'rg1',
            ),
          },
        ),
      },
    );

    final issues = validateGuestMigrationPlan(preview: preview, plan: plan);
    expect(
      issues.any((issue) => issue.contains('multiple overwrite sources')),
      isTrue,
    );
  });

  test('blocks overwrite mixed with merge for the same remote group', () {
    final plan = GuestMigrationPlan(
      projectResolutions: {
        'lp1': ProjectMergeResolution(
          localProjectId: 'lp1',
          strategy: MergeStrategy.merge,
          targetRemoteProjectId: 'rp1',
          groupResolutions: {
            'lg1': GroupMergeResolution(
              localGroupId: 'lg1',
              strategy: MergeStrategy.overwrite,
              targetRemoteGroupId: 'rg1',
            ),
          },
        ),
        'lp2': ProjectMergeResolution(
          localProjectId: 'lp2',
          strategy: MergeStrategy.merge,
          targetRemoteProjectId: 'rp1',
          groupResolutions: {
            'lg2': GroupMergeResolution(
              localGroupId: 'lg2',
              strategy: MergeStrategy.merge,
              targetRemoteGroupId: 'rg1',
            ),
          },
        ),
      },
    );

    final issues = validateGuestMigrationPlan(preview: preview, plan: plan);
    expect(
      issues.any((issue) => issue.contains('cannot mix overwrite')),
      isTrue,
    );
  });

  test('blocks duplicate camera names across multiple source groups', () {
    final plan = GuestMigrationPlan(
      projectResolutions: {
        'lp1': ProjectMergeResolution(
          localProjectId: 'lp1',
          strategy: MergeStrategy.merge,
          targetRemoteProjectId: 'rp1',
          groupResolutions: {
            'lg1': GroupMergeResolution(
              localGroupId: 'lg1',
              strategy: MergeStrategy.merge,
              targetRemoteGroupId: 'rg1',
              cameraResolutions: {
                'c1': CameraMergeResolution(localCameraId: 'c1'),
              },
            ),
          },
        ),
        'lp2': ProjectMergeResolution(
          localProjectId: 'lp2',
          strategy: MergeStrategy.merge,
          targetRemoteProjectId: 'rp1',
          groupResolutions: {
            'lg2': GroupMergeResolution(
              localGroupId: 'lg2',
              strategy: MergeStrategy.merge,
              targetRemoteGroupId: 'rg1',
              cameraResolutions: {
                'c2': CameraMergeResolution(localCameraId: 'c2'),
              },
            ),
          },
        ),
      },
    );

    final issues = validateGuestMigrationPlan(preview: preview, plan: plan);
    expect(
      issues.any((issue) => issue.contains('Camera "Shared Camera" appears')),
      isTrue,
    );
  });

  test('allows non-colliding merges', () {
    const nonCollidingPreview = GuestMigrationPreview(
      projectConflicts: [
        ProjectConflictPreview(
          localProjectId: 'lp1',
          localName: 'Local Project A',
          localDescription: 'local-a',
          remoteOptions: [remoteProject],
          groupConflicts: [
            GroupConflictPreview(
              localGroupId: 'lg1',
              localName: 'Source Group A',
              localDescription: 'group-a',
              cameraConflicts: [
                CameraConflictPreview(
                  localCameraId: 'c1',
                  localName: 'Camera One',
                  localDescription: 'camera-a',
                ),
              ],
            ),
          ],
        ),
        ProjectConflictPreview(
          localProjectId: 'lp2',
          localName: 'Local Project B',
          localDescription: 'local-b',
          remoteOptions: [remoteProject],
          groupConflicts: [
            GroupConflictPreview(
              localGroupId: 'lg2',
              localName: 'Source Group B',
              localDescription: 'group-b',
              cameraConflicts: [
                CameraConflictPreview(
                  localCameraId: 'c2',
                  localName: 'Camera Two',
                  localDescription: 'camera-b',
                ),
              ],
            ),
          ],
        ),
      ],
      sourceProjectCount: 2,
      targetProjectCount: 1,
    );

    final plan = GuestMigrationPlan(
      projectResolutions: {
        'lp1': ProjectMergeResolution(
          localProjectId: 'lp1',
          strategy: MergeStrategy.merge,
          targetRemoteProjectId: 'rp1',
          groupResolutions: {
            'lg1': GroupMergeResolution(
              localGroupId: 'lg1',
              strategy: MergeStrategy.merge,
              targetRemoteGroupId: 'rg1',
            ),
          },
        ),
        'lp2': ProjectMergeResolution(
          localProjectId: 'lp2',
          strategy: MergeStrategy.merge,
          targetRemoteProjectId: 'rp1',
          groupResolutions: {
            'lg2': GroupMergeResolution(
              localGroupId: 'lg2',
              strategy: MergeStrategy.merge,
              targetRemoteGroupId: null,
            ),
          },
        ),
      },
    );

    final issues = validateGuestMigrationPlan(
      preview: nonCollidingPreview,
      plan: plan,
    );
    expect(issues, isEmpty);
  });

  test('uses explicit target group selection before same-name fallback', () {
    const previewWithTwoRemoteGroups = GuestMigrationPreview(
      projectConflicts: [
        ProjectConflictPreview(
          localProjectId: 'lp1',
          localName: 'Local Project A',
          localDescription: 'local-a',
          remoteOptions: [
            RemoteProjectOption(
              id: 'rp1',
              name: 'Remote Project',
              description: 'remote',
              groups: [
                RemoteGroupOption(
                  id: 'target-local-group',
                  name: 'Local Group',
                  description: 'target-local',
                ),
                RemoteGroupOption(
                  id: 'target-remote-group',
                  name: 'Remote Group',
                  description: 'target-remote',
                ),
              ],
            ),
          ],
          groupConflicts: [
            GroupConflictPreview(
              localGroupId: 'lg1',
              localName: 'Local Group',
              localDescription: 'group-a',
              cameraConflicts: [
                CameraConflictPreview(
                  localCameraId: 'c1',
                  localName: 'Shared Camera',
                  localDescription: 'camera-a',
                ),
              ],
            ),
          ],
        ),
        ProjectConflictPreview(
          localProjectId: 'lp2',
          localName: 'Local Project B',
          localDescription: 'local-b',
          remoteOptions: [
            RemoteProjectOption(
              id: 'rp1',
              name: 'Remote Project',
              description: 'remote',
              groups: [
                RemoteGroupOption(
                  id: 'target-local-group',
                  name: 'Local Group',
                  description: 'target-local',
                ),
                RemoteGroupOption(
                  id: 'target-remote-group',
                  name: 'Remote Group',
                  description: 'target-remote',
                ),
              ],
            ),
          ],
          groupConflicts: [
            GroupConflictPreview(
              localGroupId: 'lg2',
              localName: 'Remote Group',
              localDescription: 'group-b',
              cameraConflicts: [
                CameraConflictPreview(
                  localCameraId: 'c2',
                  localName: 'Shared Camera',
                  localDescription: 'camera-b',
                ),
              ],
            ),
          ],
        ),
      ],
      sourceProjectCount: 2,
      targetProjectCount: 1,
    );

    final plan = GuestMigrationPlan(
      projectResolutions: {
        'lp1': ProjectMergeResolution(
          localProjectId: 'lp1',
          strategy: MergeStrategy.merge,
          targetRemoteProjectId: 'rp1',
          groupResolutions: {
            'lg1': GroupMergeResolution(
              localGroupId: 'lg1',
              strategy: MergeStrategy.merge,
              targetRemoteGroupId: 'target-local-group',
              cameraResolutions: {
                'c1': CameraMergeResolution(
                  localCameraId: 'c1',
                  strategy: MergeStrategy.overwrite,
                ),
              },
            ),
          },
        ),
        'lp2': ProjectMergeResolution(
          localProjectId: 'lp2',
          strategy: MergeStrategy.merge,
          targetRemoteProjectId: 'rp1',
          groupResolutions: {
            'lg2': GroupMergeResolution(
              localGroupId: 'lg2',
              strategy: MergeStrategy.merge,
              // Explicitly choose Local Group, despite same-name Remote Group existing.
              targetRemoteGroupId: 'target-local-group',
              cameraResolutions: {
                'c2': CameraMergeResolution(
                  localCameraId: 'c2',
                  strategy: MergeStrategy.overwrite,
                ),
              },
            ),
          },
        ),
      },
    );

    final issues = validateGuestMigrationPlan(
      preview: previewWithTwoRemoteGroups,
      plan: plan,
    );
    expect(
      issues.any((issue) => issue.contains('Camera "Shared Camera" appears')),
      isTrue,
    );
  });
}
