### Etendo ERP Development

Auto-detect Etendo projects by `gradle.properties` with `bbdd.sid`, `build.gradle` with etendo plugin, or `modules/` directory. Load the relevant `etendo-*` skill based on the task:

| Context / User request                                                                     | Skill to load           |
| ------------------------------------------------------------------------------------------ | ----------------------- |
| Detect module, show context, set active module                                             | etendo-context          |
| Create/modify tables, columns, views, references in AD                                     | etendo-alter-db         |
| Create/modify windows, tabs, fields in AD                                                  | etendo-window           |
| Create EventHandlers, Background Processes, Action Processes, Webhooks, Callouts, Servlets | etendo-java             |
| Create or configure a module                                                               | etendo-module           |
| Bootstrap a new Etendo project from scratch                                                | etendo-init             |
| Install Etendo in an existing cloned project                                               | etendo-install          |
| Configure EtendoRX flows (full SQL control)                                                | etendo-flow             |
| Register headless REST endpoints (quick webhook)                                           | etendo-headless         |
| Compile, build, deploy (smartbuild)                                                        | etendo-smartbuild       |
| Sync DB with model (update.database, export.database)                                      | etendo-update           |
| Create Jasper reports                                                                      | etendo-report           |
| Create and run tests                                                                       | etendo-test             |
| Run SonarQube analysis                                                                     | etendo-sonar            |
| Git workflow, Jira issues, commits, branches, PRs                                          | etendo-workflow-manager |
| Search Etendo documentation wiki                                                           | etendo-wiki             |
| Using AD_MESSAGE messages, JSON params, EntityStateUtils, LoggerUtils, ResponseUtils       | etendo-commons-utils    |
