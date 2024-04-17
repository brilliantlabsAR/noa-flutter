import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:noa/locationService.dart';

// Define a provider for the address
final nameProvider = StateProvider((_) => "Peter");

void updateName(String newName) {
  globalProviderContainer.read(nameProvider.notifier).state = newName;
}

// Create a global ProviderContainer
final globalProviderContainer = ProviderContainer();

// Function to fetch address from coordinates


