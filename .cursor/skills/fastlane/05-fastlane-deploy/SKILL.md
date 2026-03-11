---
description: Automatically detect release type and run the correct
  Fastlane lane to deploy metadata, screenshots, builds, or a full App
  Store release.
name: fastlane-deploy
---

# Fastlane Deploy Skill v2

## Purpose

This skill automates the final deployment stage of the App Store
pipeline.

It determines what kind of release is needed and runs the appropriate
Fastlane lane.

The user should only need to run **Deploy**, and the skill will handle
the rest.

------------------------------------------------------------------------

# Pipeline Position

Deploy should run after:

Metadata Builder Metadata Localization Keyword Refinement Preflight
Check Deploy

------------------------------------------------------------------------

# Core Responsibilities

Deploy performs the following tasks:

1.  detect repository changes
2.  determine release type
3.  run the correct Fastlane lane
4.  report deployment results

------------------------------------------------------------------------

# Step 1 --- Detect Changed Files

Inspect git diff or repository changes.

Check the following directories:

fastlane/metadata/ fastlane/screenshots/ App/ Sources/

Classify changes into categories.

------------------------------------------------------------------------

# Step 2 --- Determine Release Type

## Metadata change

If files changed inside:

fastlane/metadata/

Release type:

metadata update

Run:

fastlane ios metadata_only

------------------------------------------------------------------------

## Screenshot change

If files changed inside:

fastlane/screenshots/

Release type:

screenshots update

Run:

fastlane ios screenshots_only

------------------------------------------------------------------------

## Source code change

If files changed inside:

App/ Sources/ Swift files

Release type:

new build

Run:

fastlane ios release_build

------------------------------------------------------------------------

## Forced release

If the user explicitly requests release or publish:

Run:

fastlane ios app_store_release

------------------------------------------------------------------------

# Step 3 --- Confirm Action

Before running Fastlane, show the decision.

Example:

Detected changes: metadata

Proposed action: fastlane ios metadata_only

Proceed?

User must confirm before execution.

------------------------------------------------------------------------

# Step 4 --- Run Fastlane

Execute the selected lane.

Examples:

fastlane ios metadata_only fastlane ios screenshots_only fastlane ios
release_build fastlane ios app_store_release

------------------------------------------------------------------------

# Step 5 --- Generate Deploy Report

After deployment, report:

Deploy Report

Release Type: metadata update Lane Executed: metadata_only

Locales updated: en-US

Status: Success

If errors occur, report:

Deploy Failed

Possible cause: keywords.txt exceeds 100 characters

------------------------------------------------------------------------

# Safety Rules

Deploy must not:

-   skip confirmation
-   run build if only metadata changed
-   run full release unless requested
-   upload screenshots unnecessarily

------------------------------------------------------------------------

# Expected Outcome

After Deploy completes:

-   metadata may be updated on App Store Connect
-   screenshots may be updated
-   a new TestFlight build may be uploaded
-   a full App Store submission may occur

depending on detected changes.
