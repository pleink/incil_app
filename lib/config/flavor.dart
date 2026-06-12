enum Flavor {
  dev(
    name: 'dev',
    displayName: 'Incil CampApp (Dev)',
    oneSignalAppId: '028782a9-e433-4e82-8ccb-37b83aeb3b89',
    firebaseProjectId: 'incil-campapp-dev',
  ),
  prod(
    name: 'prod',
    displayName: 'Incil CampApp',
    oneSignalAppId: '3e8f7a53-8b01-4d37-8748-058896c8329b',
    firebaseProjectId: 'incil-campapp',
  );

  const Flavor({
    required this.name,
    required this.displayName,
    required this.oneSignalAppId,
    required this.firebaseProjectId,
  });

  final String name;
  final String displayName;
  final String oneSignalAppId;
  final String firebaseProjectId;
}
