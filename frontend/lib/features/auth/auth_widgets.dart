import 'package:flutter/material.dart';

class AuthIdentity extends StatelessWidget {
  const AuthIdentity({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 34,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.forum_outlined,
          size: 34,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      const SizedBox(height: 16),
      Text(
        'Engineering Acceptance',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        description,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class AuthErrorMessage extends StatelessWidget {
  const AuthErrorMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
