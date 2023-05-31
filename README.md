# Fyno iOS SDK

The Fyno iOS SDK enables you to utilize Fyno's services within your iOS applications, offering tools to manage remote notifications, among other features. Here are the instructions to integrate the Fyno SDK with your native iOS app using Swift.

## Requirements
- Fyno Account
- Fyno App ID, available in Settings > Keys & IDs
- iOS 13+ or iPadOS 13+ device (iPhone, iPad, iPod Touch) for testing. Xcode 14+ simulator running iOS 16+ also works.
- Mac with Xcode 12+
- p8 Authentication Token
- Your XCode Project Should can target any Apple Device excluding the Mac

## Installation

### Step 1: Add a Notification Service Extension
The FynoNotificationServiceExtension enables your iOS app to receive rich notifications with images, buttons, badges, and other features. It is also essential for Fyno's analytics capabilities.

1. In Xcode, select `File > New > Target...`
2. Choose `Notification Service Extension`, then press `Next`.
<img width="736" alt="ffb4fc9-Screen_Shot_2022-02-02_at_1 21 41_PM" src="https://github.com/fynoio/ios-sdk/assets/24733594/a54bb53e-6ef8-483d-a013-ae342feb02b0">

3. Enter the product name as `FynoNotificationServiceExtension` and press `Finish`.

<img width="731" alt="Screenshot 2023-05-24 at 4 15 07 PM" src="https://github.com/fynoio/ios-sdk/assets/24733594/861380ea-79f7-412d-836c-02c6b88fb4c4">

4. Do not Select `Activate` on the ensuing dialog.

<img width="261" alt="Screenshot 2023-05-24 at 4 23 45 PM" src="https://github.com/fynoio/ios-sdk/assets/24733594/777f266c-44a2-4bd6-a0a7-0fb334ef14c2">

5. Press `Cancel` on the `Activate scheme` prompt. This step keeps Xcode debugging your app, rather than the extension you just created. If you accidentally activated it, you could switch back to debug your app within Xcode (next to the play button).
<img width="1512" alt="Screenshot 2023-05-24 at 4 33 42 PM" src="https://github.com/fynoio/ios-sdk/assets/24733594/5f2a1483-8b49-4336-9524-91bcda92cac6">


6. In the project navigator, select the top-level project directory and pick the `FynoNotificationServiceExtension` target in the project and targets list.
7. Ensure the Deployment Target is the same value as your Main Application Target. It should be set to at least iOS 10, the version of iOS that Apple released Rich Media for push. iOS versions under 10 will not support Rich Media.
8. In the project navigator, click the `FynoNotificationServiceExtension` folder and open the `NotificationService.m` or `NotificationService.swift` and replace the entire file's contents with the provided code. Ignore any build errors at this point. We will import Fyno which will resolve these errors.

```swift
import UserNotifications
import fyno

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        fynoService.handleDidReceive(request, withContentHandler: contentHandler)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
```
This code represents a 'NotificationService' class, which is an 'UNNotificationServiceExtension'. An 'UNNotificationServiceExtension' is used to intercept and modify incoming remote push notifications before they're displayed to the user. This is especially useful when you need to add rich content to notifications, such as media attachments, or decrypt encrypted notification content.

### Step 2: Import the Fyno SDK into your Xcode project
#### Step 1
The fyno SDK can be added as a Swift Package (compatible with Objective-C as well). Check out the [instructions](#) on how to import the SDK directly from Xcode using Swift Package Manager.

#### Step 2: 
Add the Fyno SDK under Fyno Extention Service in order to enable for Fyno SDK to be handle and handle background/rich Push notifications via the service extention.

<img width="1512" alt="Screenshot 2023-05-25 at 6 54 36 PM" src="https://github.com/fynoio/ios-sdk/assets/24733594/18778808-5789-4fe0-8cee-140e7a14f82a">

### Step 3: Add Required Capabilities
This step ensures that your project can receive remote notifications. Apply these steps only to the main application target and not for the Notification Service Extension.

1. Select the root project > your main app target and "Signing & Capabilities".
2. If you do not see `Push Notifications` enabled, click `+ Capability` and add `Push Notifications`.
<img width="1512" alt="Screenshot 2023-05-24 at 6 57 13 PM" src="https://github.com/fynoio/ios-sdk/assets/24733594/e8ca84e0-f6b2-473c-ad4d-5fd3a59751db">

3. Click `+ Capability` and add `Background Modes`. Then check `Remote notifications`.
<img width="1512" alt="Screenshot 2023-05-24 at 6 59 38 PM" src="https://github.com/fynoio/ios-sdk/assets/24733594/1fcadb3a-fcd1-44b2-95ff-07fba2759431">

### Step 4: Add the Fyno Initialization Code
#### Direct Implementation
Navigate/Create to your AppDelegate file and add the Fyno initialization code.

```swift
import Foundation
import UIKit
import fyno

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate  {
    let fynosdk  =  fyno.app

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        fynosdk.requestNotificationAuthorization { granted in
            if granted {
                DispatchQueue.main.async {
                    self.fynosdk.registerForRemoteNotifications()
                }
            }
        }
       fynosdk.enableTestMode(testEnabled: false)
       return true
    }


    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        fynosdk.handleRemoteNotification(userInfo: userInfo, fetchCompletionHandler: completionHandler)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Send the device token to fynoServer
        let token = deviceToken.map { String(format: "%.2hhx", $0) }.joined()
        
        fynosdk.initializeApp(WSID: YOUR_WORKSPACE_ID,api_key: YOUR_API_KEY, integrationID: YOUR_INTEGRATION_ID, deviceToken: token){
                    result in
                    switch result{
                    case .success(_):
                        self.fynosdk.createUserProfile(distinctID: "your_database_unique_identifier",name: "John Doe"){result in
                                            switch result{
                                            case .success(let success):
                                            print(success)
                                            case .failure(let error):
                                            print(error)
                                            }
                                        }
                        
                    case .failure(let error):
                        print(error)
                         
                    }
                }
            }
  
  // DELETE USER PROFILE
  //SIGNOUT
  /**
  fynosdk.deleteProfile(name: anonymous_profile_name){result in
                switch result{
                case .success(let success):
                    print(success)
                case .failure(let error):
                    print(error)
                }
            }
  **/
  
    
}
```

#### Fyno iOS SDK Implementation Step by Step Guide

The Fyno iOS SDK allows you to leverage Fyno's services in your iOS applications. It provides you with a set of tools to handle remote notifications, among other features.

##### Installation

The SDK can be found at the following GitHub repository:

`https://github.com/fynoio/ios-sdk.git`

##### Initial Setup

1. Import `fyno`, `UIKit` in the Application Delegate Swift file.

```swift
import UIKit
import fyno
```

2. Initialize an instance of the Fyno class and set it as the delegate for the User Notification Center.

```swift
let fynoInstance = fyno.app
```

##### Request Notification Authorization

Use the `requestNotificationAuthorization` method to ask the user for notification permissions. This function accepts a closure that takes a Boolean parameter, which indicates whether permission was granted.

```swift
fynoInstance.requestNotificationAuthorization { (granted) in
    if granted {
        // Permission granted
    } else {
        // Permission not granted
    }
}
```

##### Register for Remote Notifications

Use the `registerForRemoteNotifications` function to register the app for receiving remote notifications.

```swift
fynoInstance.registerForRemoteNotifications()
```

##### Handle Notifications

The SDK provides several methods to handle notifications:

1. `handleRemoteNotification`: This method is used to handle a remote notification. It accepts the notification's user info and a completion handler.

```swift
fynoInstance.handleRemoteNotification(userInfo: userInfo) { (fetchResult) in
    // Handle fetch result
}
```

2. `userNotificationCenter(_:willPresent:withCompletionHandler:)`: This method is called when a notification is received while the app is active.

```swift
fynoInstance.userNotificationCenter(center, willPresent: notification) { (options) in
    // Handle presentation options
}
```

3. `userNotificationCenter(_:didReceive:withCompletionHandler:)`: This method is called when a user interacts with a notification, such as clicking or dismissing it.

```swift
fynoInstance.userNotificationCenter(center, didReceive: response) { 
    // Handle user response
}
```

#### Step 5: Initialize/Connect Fyno sdk
This function is crucial to connect with our Fyno application. It needs to be called before creating a profile when the app is starting up with the following configuration:

```swift
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Send the device token to fynoServer
        let token = deviceToken.map { String(format: "%.2hhx", $0) }.joined()
        
         fynosdk.initializeApp(WSID: YOUR_WORKSPACE_ID,api_key: YOUR_API_KEY, integrationID: YOUR_INTEGRATION_ID, deviceToken: token){
                    result in
                    switch result{
                    case .success(_)
                        
                    case .failure(let error):
                        print(error)
                         
                    }
                }
            }
```

#### Step 6: Create user profile for targeting
The `createUserProfile(payload:completionHandler:)` method creates a user profile using a `Payload` instance and sends a POST request to the server. It calls a completion handler with the result.

```swift
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Send the device token to fynoServer
        let token = deviceToken.map { String(format: "%.2hhx", $0) }.joined()
       fynosdk.initializeApp(WSID: YOUR_WORKSPACE_ID,api_key: YOUR_API_KEY, integrationID: YOUR_INTEGRATION_ID, deviceToken: token){
                    result in
                    switch result{
                    case .success(_):
                         self.fynosdk.createUserProfile(distinctID: "Testing-Khush",name: "Test Man"){result in
                                            switch result{
                                            case .success(let success):
                                            print(success)
                                            case .failure(let error):
                                            print(error)
                                            }
                                        }
                        
                    case .failure(let error):
                        print(error)
                         
                    }
                }
            }
```

#### Step 7: Delete user profile 
The `deleteProfile()` method deletes an existing profile using a `Payload` instance and sends a POST request to the server. It calls a completion handler with the result.

```swift
fynosdk.deleteProfile(name: currentUser){result in
                switch result{
                case .success(let success):
                    print(success)
                case .failure(let error):
                    print(error)
                }
            }
```

#### Step 8: Switch to test Environment
The `fynosdk.enableTestMode(testEnabled:)` method allows the user to switch from the default 'live' environment to 'test' mode within the Fyno application.

```swift
fynosdk.enableTestMode(testEnabled: true)
```

### Troubleshooting
If you encounter issues, see our [iOS troubleshooting guide](#).
Try the example project on our [Github repository](#).
If stuck, contact support directly or email support@fyno.io for help.
For faster assistance, please provide:
- Your Fyno secret key
- Details, logs, and/or screenshots of the issue.
