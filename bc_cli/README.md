# bc_cli

bc_cli is a Dart-based command-line interface (CLI) application that demonstrates how to interact with brainCloud services. This example provides a foundational understanding of integrating brainCloud’s backend capabilities within a Dart environment.

## Features  
* User Authentication: Authenticate users securely using brainCloud’s authentication mechanisms.
* Data Management: Perform basic operations such as creating, reading, updating, and deleting data.
* Cloud Code Execution: Invoke brainCloud’s cloud code scripts from the CLI.

## Prerequisites

Before running the application, ensure you have the following installed:
* Dart SDK

## Getting Started
1.	Clone the Repository:
```shell
git clone https://github.com/getbraincloud/examples-dart.git
```

2.	Navigate to the bc_cli Directory:
```shell
cd examples-dart/bc_cli
```

3.	Install Dependencies:
```shell
dart pub get
```

4.	Configure brainCloud:
* Obtain your brainCloud app credentials from the brainCloud portal.
* Update the parameters MY_APPID and MY_SECRET with your app ID, secret, and others as necessary.

5.	Run the Application:
```shell
dart run bin/bc_cli.dart --appid MY_APPID --appsecret MY_SECRET 
```

To get A user statistics:
```shell
dart run bin/bc_cli.dart --appid MY_APPID --appsecret MY_SECRET  --user USER@EMAIL --password USER_PASSWORD
```
