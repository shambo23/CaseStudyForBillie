### Billie - Case Study ###

### [MANDATORY] Post-Deployment Steps

After deployment, ensure that the **Named Principle Access** permission set is assigned to the user performing the testing. Salesforce requires permissions to be explicitly assigned for Named Credentials. In this project, Named Credentials are used instead of Remote Site Settings.

### Testing Process

1. Open the Developer Console in your Salesforce org.
2. Navigate to the Anonymous Execution window within the Developer Console.
3. Execute the following script:
    ```apex
    System.enqueueJob(new MostPublishedBookService());
    ```
4. Please open **Most Published Books** tab and you should be able to see the results in tabular format sorted by Edition number in Descending order. 

### INSTALLATION PROCESS
## Salesforce Packaging: Clone, Connect Dev Hub, Create Unlocked Package, Install in Scratch Org

Follow these steps on macOS using the Salesforce CLI (sf).

### Prerequisites
- Dev Hub enabled in your Salesforce org.
- Salesforce CLI installed:
```sh
brew install salesforce-cli
# or
npm install -g @salesforce/cli
```

### 1) Clone the repository in your local folder and open it via your IDE
```sh
git clone https://github.com/shambo23/CaseStudyForBillie.git

```
### 2) Authorize your personal org and ensure you org has Dev Hub enabled

### 3) Authenticate to your Dev Hub
```sh
sf org login web --alias DevHub --set-default-dev-hub
sf org display --target-org DevHub
```

### 4) Create an Unlocked Package (one-time per package)
- Ensure your source path (e.g., force-app) exists and is referenced in sfdx-project.json.
```sh
sf package create \
  --name "YourPkgName" \
  --package-type Unlocked \
  --path force-app \
  --description "Unlocked package for project" \
  --target-dev-hub DevHub
```

### 5) Create a Package Version
```sh
sf package version create \
  --package "YourPkgName" \
  --code-coverage \
  --installation-key-bypass \
  --wait 60 \
  --target-dev-hub DevHub
```
- Get the Subscriber Package Version Id (starts with 04t):
```sh
sf package version list --packages "YourPkgName" --target-dev-hub DevHub
```

### 6) Create a Scratch Org
- Uses config/project-scratch-def.json (adjust if your file differs).
```sh
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias ScratchPkgOrg \
  --duration-days 7 \
  --target-dev-hub DevHub \
  --set-default
```

### 7) Ensure to store the package id and version Id (Will be used in next step)

- Uses config/project-scratch-def.json (adjust if your file differs).
```sh
sf package version list --packages <YourPackageNameOrAlias> --target-dev-hub <DevHubAlias> --json \
  | jq -r '.result[0].SubscriberPackageVersionId'
```
OR 
- Get the Subscriber Package Version Id (starts with 04t):
```sh
sf package version list --packages "YourPkgName" --target-dev-hub DevHub
```

### 8) Install the Package into the Scratch Org
- Using the 04t Id:
```sh
sf package install \
  --package 04tXXXXXXXXXXXXXX \
  --target-org ScratchPkgOrg \
  --installation-key-bypass \
  --publish-wait 10 \
  --wait 30
```
- Or using semantic version (if mapped in sfdx-project.json):
```sh
sf package install \
  --package "YourPkgName@x.y.z" \
  --target-org ScratchPkgOrg \
  --publish-wait 10 \
  --wait 30
```
[ If you face issue please add   --installation-key-bypass \ to the command ]

### 9) Validate
```sh
sf package installed list --target-org ScratchPkgOrg
sf org open --target-org ScratchPkgOrg
```

### Notes
- Run npm install if the repo has a package.json with tooling.
- If creation fails, check details:
```sh
sf package version report --package "YourPkgName" --target-dev-hub DevHub
```

### 10) Please perform mandatory Post Deployment steps and test the feature. Please refer to the top section of README file for the steps.


