import 'package:easy_localization/easy_localization.dart';
import 'package:eyadati/user/userRegistrationUi.dart';
import 'package:eyadati/user/user_login_page.dart';
import 'package:eyadati/utils/markdown_viewer_screen.dart';
import 'package:flutter/material.dart';

class UserAuthSelectionScreen extends StatelessWidget {
  const UserAuthSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('user_authentication'.tr())),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserLoginPage(),
                    ),
                  );
                },
                child: Text('already_have_account_login'.tr()),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserOnboardingPages(),
                    ),
                  );
                },
                child: Text('create_new_account'.tr()),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MarkdownViewerScreen(
                        title: "privacy_policy".tr(),
                        markdownAssetPath: "privacy_policy.md",
                      ),
                    ),
                  );
                },
                child: Text(
                  "privacy_policy".tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
