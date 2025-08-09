### Case Study For Billie ###

**###POST DEPLOYMENT STEPS###**

Please ensure to add **Named_Principle_Access** permission set to the user who is testing. As for Named Credentials SF has made it mandatory to assign permissions to the users. In this project Named Credential is used instead of Remote Site Settings

**###TESTING PROCESS###**

Please open developer console from your org and open Annonymous window from Dev console.
Then please execute the below script -
**System.enqueueJob(new MostPublishedBookService());**

**###INSTALLATION PROCESS####**
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

### 1) Clone the repository
```sh
git clone https://github.com/shambo23/CaseStudyForBillie.git.git

```

### 2) Authenticate to your Dev Hub
```sh
sf org login web --alias DevHub --set-default-dev-hub
sf org display --target-org DevHub
```

### 3) Create an Unlocked Package (one-time per package)
- Ensure your source path (e.g., force-app) exists and is referenced in sfdx-project.json.
```sh
sf package create \
  --name "YourPkgName" \
  --package-type Unlocked \
  --path force-app \
  --description "Unlocked package for project" \
  --target-dev-hub DevHub
```

### 4) Create a Package Version
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

### 5) Create a Scratch Org
- Uses config/project-scratch-def.json (adjust if your file differs).
```sh
sf org create scratch \
  --definition-file config/project-scratch-def.json \
  --alias ScratchPkgOrg \
  --duration-days 7 \
  --target-dev-hub DevHub \
  --set-default
```

### 6) Install the Package into the Scratch Org
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
  --installation-key-bypass \
  --publish-wait 10 \
  --wait 30
```

### 7) Validate
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


