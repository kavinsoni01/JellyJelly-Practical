# JellyJellyTest iOS App

## Overview

JellyJellyTest is an iOS application focused on providing a dynamic video consumption experience, allowing users to browse a feed of short-form videos, interact with content, and manage videos recorded or saved through the app. It also includes functionality for video recording.

## Features

-   **Video Feed:**
    -   Vertical, full-screen video playback in a scrollable feed.
    -   Displays video title, summary, and the owner's profile information (name, avatar).
    -   Interactive elements: Like (with animation), Share functionality.
    -   Tap-to-toggle play/pause with an information overlay appearing when paused.
    -   Sound on/off control for video playback.
    -   Automatic advance to the next video upon completion of the current one.
    -   Pull-to-refresh capability for updating the video feed.
-   **Video Recording:**
    -   (Goal/In-Progress) Camera functionality, with past explorations into dual Point-of-View (front and back camera) synchronized recordings (15s limit), aiming for saving/upload.
    -   Custom animated record button.
    -   Saving recorded videos to a dedicated album in the Photo Library.
-   **Camera Roll:**
    -   Displays videos from the app-specific "Jelly Jelly Videos" album.
    -   Grid layout showcasing video thumbnails.
    -   Tap-to-play functionality for videos in the roll.
    -   Ability to delete videos directly from the app's camera roll.
    -   A user-friendly placeholder view (image and text) when no videos are present.
-   **User Profiles:**
    -   User profile information for video creators is dynamically fetched from an API.
    -   A caching mechanism (`userProfileCache` in `FeedViewModel`) is implemented to reduce redundant API calls and improve performance.
-   **Launch Screen:**
    -   A custom-designed launch screen providing initial app branding.

## Thought Process & Design Decisions

### 1. Video Feed (`FeedViewController`, `FeedCollectionCell`, `FeedViewModel`)

-   **Design Goal:** To create an immersive and intuitive video browsing experience, mirroring the engagement of popular short-form video platforms.
-   **Implementation Details:**
    -   A `UICollectionView` with a vertical `UICollectionViewFlowLayout` is used, with `isPagingEnabled` to ensure one video occupies the screen at a time.
    -   `FeedCollectionCell` is responsible for embedding `VideoPlayerView` and handling individual video playback and UI.
    -   The `FeedViewModel` adheres to MVVM principles, managing:
        -   Fetching the list of videos via `callExploreVideoListAPI`.
        -   Fetching user profiles for video owners (`requestUserProfileIfNeeded`), including proactive fetching for visible cells.
        -   Caching fetched user profiles to optimize performance.
        -   Tracking the `currentPlayingIndex` to manage video playback and state.
        -   Handling the pull-to-refresh logic.
-   **Tradeoffs & Considerations:**
    -   **User Profile Caching:**
        -   *Pro:* Significantly reduces API requests for repeated user profiles, leading to faster UI updates and lower server load.
        -   *Con:* The cache can become stale. Currently, it's cleared when the entire video list is refreshed. More sophisticated cache invalidation strategies could be implemented if needed (e.g., time-based expiry).
    -   **Proactive Profile Fetching:**
        -   Initially, profiles might have been fetched only for the active video.
        -   *Decision:* Implemented proactive fetching for visible cells (if not cached) in `collectionView(_:cellForItemAt:)` by calling `viewModel.requestUserProfileIfNeeded`.
        -   *Pro:* Improves perceived performance as user info might appear sooner.
        -   *Con:* Slightly increases initial network activity when new cells appear. Managed by checking `profileFetchInProgress` to avoid redundant calls for the same ID.
    -   **Video Playback Management:** The view controller manages which cell should play based on visibility and scrolling, delegating play/pause commands to the cell.

### 2. Camera Roll (`CameraRollViewController`, `CameraRollCell`)

-   **Design Goal:** Offer users a straightforward way to access and manage videos created or saved by the JellyJellyTest app.
-   **Implementation Details:**
    -   Uses a `UICollectionView` with a standard grid layout.
    -   `CameraRollCell` displays video thumbnails fetched using `PHCachingImageManager` and shows video titles (derived from filenames or creation dates).
    -   Videos are sourced from a specific `PHAssetCollection` named "Jelly Jelly Videos."
    -   Deletion of videos is handled via `PHPhotoLibrary.shared().performChanges(_:completionHandler:)`.
    -   A placeholder view is displayed if the "Jelly Jelly Videos" album is empty or inaccessible.
-   **Tradeoffs & Considerations:**
    -   **Custom Photo Album:**
        -   *Pro:* Keeps app-specific content neatly organized within the user's Photo Library.
        -   *Con:* Requires logic to create or find this album. If creation fails or permissions are tricky, it could be a point of friction.
    -   **Cell Visuals (Shadows & Corner Radius):**
        -   Achieved using a common UIKit technique: an outer `containerView` for the shadow (`layer.masksToBounds = false`) and an inner `viewBack` for the content with `cornerRadius` and `clipsToBounds = true`. The `shadowPath` is updated in `layoutSubviews` for optimal performance.

### 3. Video Recording (`CameraViewController`, `CameraService`)

-   **Design Goal:** Enable users to capture video content directly within the app, with an eye towards unique features like dual-camera perspectives (as explored in Note #11 of project memory).
-   **Implementation (based on current structure and project notes):**
    -   `CameraViewController` manages the `AVFoundation` setup, camera preview, and recording initiation/stopping.
    -   `CameraService` likely abstracts `AVFoundation` complexities, making the view controller cleaner.
    -   `AnimatedRecordButton` provides a custom, interactive UI element for recording.
    -   Recorded videos are saved to the "Jelly Jelly Videos" album via `PhotoLibraryService`.
-   **Tradeoffs & Considerations (referencing project memory Note #11):**
    -   **Dual Camera Functionality:**
        -   *Challenge:* True simultaneous dual-camera capture (e.g., split-screen from front and back cameras) requires `AVCaptureMultiCamSession`.
        -   *Tradeoff:* `AVCaptureMultiCamSession` is only available on newer, supported iPhone hardware (iPhone XR/XS and later). On unsupported devices or with a basic `AVCaptureSession`, only one camera can be actively streaming/recording at a time. This is a significant hardware-dependent limitation.
    -   **Permissions:** Robust handling of camera and microphone permissions is critical.
    -   **Video Processing:** Currently saving to Photos. Future enhancements might involve in-app processing, transcoding, or direct uploads.

### 4. General UI & Architecture

-   **UI Construction:** Leverages Storyboards (`Main.storyboard`, `LaunchScreen.storyboard`) for overall scene layout and XIBs for reusable cell designs (`FeedCollectionCell.xib`, `CameraRollCell.xib`).
-   **Architectural Pattern:** MVVM (Model-View-ViewModel) is utilized, notably with `FeedViewModel`, to separate business logic and state management from the `FeedViewController`.
-   **Service Layer:** Dedicated services (`ApiService`, `CameraService`, `PhotoLibraryService`) encapsulate specific domains of responsibility, promoting modularity and testability.
-   **Error Handling:** Current error handling primarily involves `print` statements for debugging in ViewModels and ViewControllers, with delegate patterns to communicate some failures. User-facing errors (e.g., share errors, video deletion failures) are presented via `UIAlertController`.

## Design Sketches / UI Mockups

While formal design sketches are not embedded here, the UI design can be inferred from the existing Storyboard and XIB files:

*   **Launch Screen (`LaunchScreen.storyboard`):**
    *   *Sketch:* A centrally positioned app icon (`appicon`) with the app title "Jelly Jelly" prominently displayed above it. Below the icon, a tagline reads: "This is the Jelly Challenge Test, created by Kavin Soni." This establishes the initial brand identity upon app launch.
    *   *(This is directly derived from your `/Users/codeflix/Desktop/Project/Reference project/JellyJellyTest/JellyJellyTest/Base.lproj/LaunchScreen.storyboard`)*

*   **Video Feed Cell (`FeedCollectionCell.xib` implies this sketch):**
    *   A full-screen area dedicated to `VideoPlayerView`.
    *   Overlaid UI elements would include:
        *   Bottom-left: User avatar (`userImage`), username (`lblUserName`).
        *   Below username: Video title (`lblTitle`).
        *   Expandable/scrollable area for video summary/description (`lblUserDescriotion`).
        *   Right-hand side (vertically stacked): Buttons for Like (`likeButton`), Share (`shareButton`), and potentially others.
        *   Top-right or similar: Sound on/off toggle (`btnSoundOnOff`).
    *   An animated heart (`heartImageView`) would appear centrally on double-tap for "like."
    *   A semi-transparent `viewInfo` overlay would appear when the video is tapped to pause, showing more detailed information.

*   **Camera Roll Cell (`CameraRollCell.xib` implies this sketch):**
    *   A rectangular cell with rounded corners and a subtle drop shadow.
    *   A `thumbnailImageView` filling most of the cell.
    *   A `lblTitle` at the bottom displaying the video's name or date.
    *   A small `deleteButton` (e.g., trash icon) overlaid on one of the corners of the thumbnail.

*   **Camera Roll - Empty State (Conceptual Sketch based on implementation):**
    *   A full-screen view replacing the collection view.
    *   Centrally: An icon or image representing "no videos" (e.g., the "no-video" asset).
    *   Below the image: Text stating, "You have no videos in Jelly Jelly. You can create a new one!"

## Future Considerations / Potential Improvements

-   **Advanced Video Editing Tools:** Filters, text overlays, trimming, stitching.
-   **Robust Backend Integration:** User authentication, cloud video storage, comments, user following, personalized feeds.
-   **Enhanced Error Handling:** More user-friendly in-app messages, retry options for network requests.
-   **Accessibility (A11y):** Thorough implementation of VoiceOver labels, dynamic type support, and other accessibility features.
-   **Testing:** Comprehensive suite of unit tests for ViewModels and services, and UI tests for critical user flows.
-   **VideoPlayerView Enhancements:** Custom controls, buffering indicators, more detailed error reporting for playback issues.
-   **MultiCam Implementation:** For devices that support `AVCaptureMultiCamSession`, implement true dual-camera recording.
-   **Offline Support:** Caching video data for offline viewing in the feed.

This README provides a snapshot of the JellyJellyTest app's development, design considerations, and architectural choices based on our collaborative work.