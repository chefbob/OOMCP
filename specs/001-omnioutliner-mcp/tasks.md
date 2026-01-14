# Tasks: OmniOutliner MCP Server

**Input**: Design documents from `/specs/001-omnioutliner-mcp/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/mcp-tools.md, quickstart.md

**Tests**: Not explicitly requested - tests are included for core functionality to meet constitution principle V (Test Coverage - 80% target).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md, this is a native macOS Xcode project:

```text
OmniOutlinerMCP/
├── OmniOutlinerMCP.xcodeproj
├── OmniOutlinerMCP/
│   ├── App/                    # Entry point, AppState, Preferences
│   ├── Views/                  # SwiftUI menu bar and settings views
│   ├── Server/                 # HTTP server, MCP protocol, JSON-RPC
│   ├── Tools/                  # MCP tool implementations
│   ├── OmniOutliner/           # NSAppleScript bridge, JXA scripts
│   └── Resources/              # Assets, localization
├── OmniOutlinerMCPTests/       # Unit and integration tests
└── OmniOutlinerMCPUITests/     # UI automation tests
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Xcode project initialization and basic structure

- [x] T001 Create Xcode project OmniOutlinerMCP.xcodeproj with macOS app target (Menu Bar App template)
- [x] T002 Configure project settings: deployment target macOS 12, Swift 5.9, SwiftUI lifecycle
- [x] T003 [P] Add Vapor 4.x dependency via Swift Package Manager in Package.swift
- [x] T004 [P] Create folder structure: App/, Views/, Server/, Tools/, OmniOutliner/, Resources/
- [x] T005 [P] Configure entitlements for Apple Events (automation permission) in OmniOutlinerMCP.entitlements
- [x] T006 [P] Add app icons and menu bar icons to Resources/Assets.xcassets
- [x] T007 [P] Create Localizable.strings in Resources/ for user-facing strings

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T008 Implement data models (Document, Row, RowState, Column) in OmniOutlinerMCP/OmniOutliner/DocumentModel.swift
- [x] T009 [P] Implement error types (OutlinerError, ErrorCode enum) in OmniOutlinerMCP/OmniOutliner/OmniOutlinerError.swift
- [x] T010 Implement OmniOutlinerBridge with NSAppleScript execution wrapper in OmniOutlinerMCP/OmniOutliner/OmniOutlinerBridge.swift
- [x] T011 [P] Create JXA script templates for Omni Automation in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T012 Implement MCP protocol types (JSONRPCRequest, JSONRPCResponse, MCPMessage) in OmniOutlinerMCP/Server/MCPProtocol.swift
- [x] T013 Implement JSON-RPC 2.0 handler in OmniOutlinerMCP/Server/JSONRPCHandler.swift
- [x] T014 Implement MCPRouter for tool dispatch in OmniOutlinerMCP/Server/MCPRouter.swift
- [x] T015 Implement HTTP server lifecycle (start/stop) using Vapor in OmniOutlinerMCP/Server/MCPServer.swift
- [x] T016 [P] Implement ToolRegistry for tool registration and lookup in OmniOutlinerMCP/Tools/ToolRegistry.swift
- [x] T017 [P] Write unit tests for DocumentModel in OmniOutlinerMCPTests/OmniOutlinerTests/DocumentModelTests.swift
- [x] T018 [P] Write unit tests for MCPProtocol in OmniOutlinerMCPTests/ServerTests/MCPProtocolTests.swift
- [x] T019 [P] Write unit tests for JSONRPCHandler in OmniOutlinerMCPTests/ServerTests/JSONRPCHandlerTests.swift

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 4 - Simple Installation and Startup (Priority: P1)

**Goal**: Non-technical users can install via DMG and run the app from the menu bar with minimal setup

**Independent Test**: Download DMG, drag to Applications, launch app, see menu bar icon appear with status indicator

**Why First**: US4 is the shell that contains everything else. The menu bar app must exist before query/modify tools can be accessed.

### Implementation for User Story 4

- [x] T020 [US4] Implement AppState ObservableObject (server status, connection state) in OmniOutlinerMCP/App/AppState.swift
- [x] T021 [US4] Implement Preferences wrapper (port, auto-launch) using UserDefaults in OmniOutlinerMCP/App/Preferences.swift
- [x] T022 [US4] Implement main app entry point with MenuBarExtra in OmniOutlinerMCP/App/OmniOutlinerMCPApp.swift
- [x] T023 [P] [US4] Implement StatusIndicator view (green/yellow/red) in OmniOutlinerMCP/Views/StatusIndicator.swift
- [x] T024 [P] [US4] Implement MenuBarView dropdown content in OmniOutlinerMCP/Views/MenuBarView.swift
- [x] T025 [P] [US4] Implement SetupInstructionsView for ChatGPT/Claude setup guides in OmniOutlinerMCP/Views/SetupInstructionsView.swift
- [x] T026 [P] [US4] Implement PreferencesView settings window in OmniOutlinerMCP/Views/PreferencesView.swift
- [x] T027 [US4] Wire AppState to MCPServer start/stop in OmniOutlinerMCP/App/OmniOutlinerMCPApp.swift
- [x] T028 [US4] Implement auto-launch on login via Login Items API in OmniOutlinerMCP/App/Preferences.swift
- [x] T029 [US4] Add user-friendly error messages for common failures in OmniOutlinerMCP/OmniOutliner/OmniOutlinerError.swift
- [x] T030 [P] [US4] ~~Write UI tests for menu bar interactions~~ N/A - XCUITest is unreliable for menu bar apps; MenuBarExtra and NSStatusItem are not accessible via XCUITest automation. Manual testing verified.

**Checkpoint**: App launches, shows menu bar icon, can start/stop server, displays setup instructions

---

## Phase 4: User Story 1 - Query Outline Content (Priority: P1) MVP

**Goal**: Users can ask questions about their OmniOutliner documents and receive accurate responses

**Independent Test**: Open OmniOutliner document, ask ChatGPT "What's in my outline?", receive accurate summary of document content

### Implementation for User Story 1

- [x] T031 [US1] Implement JXA script for get_current_document in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T032 [US1] Implement JXA script for get_outline_structure in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T033 [US1] Implement JXA script for get_row in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T034 [US1] Implement JXA script for get_row_children in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T035 [US1] Implement JXA script for search_outline in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T036 [US1] Implement get_current_document tool handler in OmniOutlinerMCP/Tools/QueryTools.swift
- [x] T037 [US1] Implement get_outline_structure tool handler in OmniOutlinerMCP/Tools/QueryTools.swift
- [x] T038 [US1] Implement get_row tool handler in OmniOutlinerMCP/Tools/QueryTools.swift
- [x] T039 [US1] Implement get_row_children tool handler in OmniOutlinerMCP/Tools/QueryTools.swift
- [x] T040 [US1] Implement search_outline tool handler in OmniOutlinerMCP/Tools/QueryTools.swift
- [x] T041 [US1] Register query tools in ToolRegistry in OmniOutlinerMCP/Tools/ToolRegistry.swift
- [x] T042 [P] [US1] Write unit tests for QueryTools (mocked OmniOutliner) in OmniOutlinerMCPTests/ToolTests/QueryToolsTests.swift
- [x] T043 [US1] Write integration tests with real OmniOutliner in OmniOutlinerMCPTests/IntegrationTests/QueryIntegrationTests.swift

**Checkpoint**: User Story 1 complete - users can query outline content via AI agent

---

## Phase 5: User Story 2 - Modify Outline Content (Priority: P2)

**Goal**: Users can add, edit, move, and delete rows through natural language commands

**Independent Test**: Ask ChatGPT "Add a task called 'Review budget' under Tasks", verify row appears in OmniOutliner

### Implementation for User Story 2

- [x] T044 [US2] Implement JXA script for add_row in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T045 [US2] Implement JXA script for update_row in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T046 [US2] Implement JXA script for move_row in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T047 [US2] Implement JXA script for delete_row in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T048 [US2] Implement add_row tool handler in OmniOutlinerMCP/Tools/ModifyTools.swift
- [x] T049 [US2] Implement update_row tool handler in OmniOutlinerMCP/Tools/ModifyTools.swift
- [x] T050 [US2] Implement move_row tool handler in OmniOutlinerMCP/Tools/ModifyTools.swift
- [x] T051 [US2] Implement delete_row tool handler with confirmation logic in OmniOutlinerMCP/Tools/ModifyTools.swift
- [x] T052 [US2] Add undo notification message to all modify responses in OmniOutlinerMCP/Tools/ModifyTools.swift
- [x] T053 [US2] Register modify tools in ToolRegistry in OmniOutlinerMCP/Tools/ToolRegistry.swift
- [x] T054 [P] [US2] Write unit tests for ModifyTools (mocked OmniOutliner) in OmniOutlinerMCPTests/ToolTests/ModifyToolsTests.swift
- [x] T055 [US2] Write integration tests with real OmniOutliner in OmniOutlinerMCPTests/IntegrationTests/ModifyIntegrationTests.swift

**Checkpoint**: User Story 2 complete - users can modify outline content via AI agent

---

## Phase 6: User Story 3 - AI-Assisted Content Synthesis (Priority: P2)

**Goal**: Users can get summaries, insights, and draft content based on their outline data

**Independent Test**: Ask ChatGPT "Summarize this document", receive coherent summary of outline content

### Implementation for User Story 3

- [x] T056 [US3] Implement JXA script for get_section_content (plain/markdown/structured output) in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T057 [US3] Implement JXA script for insert_content (single and hierarchical) in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T058 [US3] Implement get_section_content tool handler in OmniOutlinerMCP/Tools/SynthesisTools.swift
- [x] T059 [US3] Implement insert_content tool handler in OmniOutlinerMCP/Tools/SynthesisTools.swift
- [x] T060 [US3] Register synthesis tools in ToolRegistry in OmniOutlinerMCP/Tools/ToolRegistry.swift
- [x] T061 [P] [US3] Write unit tests for SynthesisTools (mocked OmniOutliner) in OmniOutlinerMCPTests/ToolTests/SynthesisToolsTests.swift
- [x] T062 [US3] Write integration tests with real OmniOutliner in OmniOutlinerMCPTests/IntegrationTests/SynthesisIntegrationTests.swift

**Checkpoint**: User Story 3 complete - users can synthesize and insert content via AI agent

---

## Phase 7: User Story 5 - Connection Status Visibility (Priority: P3)

**Goal**: Users can see at a glance whether the MCP server is connected and working

**Independent Test**: Launch app, see green indicator when OmniOutliner open; close OmniOutliner, see yellow indicator

### Implementation for User Story 5

- [x] T063 [US5] Implement JXA script for check_connection in OmniOutlinerMCP/OmniOutliner/JXAScripts.swift
- [x] T064 [US5] Implement check_connection tool handler in OmniOutlinerMCP/Tools/QueryTools.swift
- [x] T065 [US5] Add periodic connection polling to AppState in OmniOutlinerMCP/App/AppState.swift
- [x] T066 [US5] Update StatusIndicator to reflect real-time connection state in OmniOutlinerMCP/Views/StatusIndicator.swift
- [x] T067 [US5] Add connection status to menu bar dropdown in OmniOutlinerMCP/Views/MenuBarView.swift
- [x] T068 [US5] Add notification when connection lost in OmniOutlinerMCP/App/AppState.swift
- [x] T069 [P] [US5] Write unit tests for connection status logic in OmniOutlinerMCPTests/ToolTests/ConnectionStatusTests.swift

**Checkpoint**: User Story 5 complete - users can see real-time connection status

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Security hardening, performance optimization, and distribution preparation

- [x] T070 [P] Input validation and sanitization for all tool parameters in OmniOutlinerMCP/Tools/ToolRegistry.swift
- [x] T071 [P] Ensure HTTP server binds only to localhost in OmniOutlinerMCP/Server/MCPServer.swift
- [x] T072 [P] Performance testing with 5,000-row outline per SC-004 in OmniOutlinerMCPTests/IntegrationTests/PerformanceTests.swift
- [x] T073 [P] Review and update all user-facing strings in Resources/Localizable.strings
- [x] T074 Configure code signing with Developer ID certificate in Xcode project settings
- [x] T075 Configure notarization settings in Xcode project (hardened runtime enabled, entitlements configured)
- [x] T076 Create DMG installer with background image and Applications alias (scripts/create-dmg.sh)
- [ ] T077 Test full installation flow on clean macOS machine (manual testing required)
- [x] T078 Validate quickstart.md instructions match actual app behavior
- [x] T079 Final security review per constitution principle VI

---

## Post-MVP Additions (Completed)

**Purpose**: Features added after initial task planning

- [x] T080 Multi-document support: list_documents tool in OmniOutlinerMCP/Tools/QueryTools.swift
- [x] T081 Multi-document support: get_all_documents_content tool in OmniOutlinerMCP/Tools/QueryTools.swift
- [x] T082 Multi-document support: Add documentName parameter to existing tools
- [x] T083 create_document tool in OmniOutlinerMCP/Tools/ModifyTools.swift

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **US4 Installation (Phase 3)**: Depends on Foundational - creates app shell
- **US1 Query (Phase 4)**: Depends on US4 (app must exist) - MVP milestone
- **US2 Modify (Phase 5)**: Depends on US1 (query tools inform modification targets)
- **US3 Synthesis (Phase 6)**: Can run parallel with US2 after US1
- **US5 Status (Phase 7)**: Can run parallel with US2/US3 after US4
- **Polish (Phase 8)**: Depends on all desired user stories being complete

### User Story Dependencies

```
Phase 1 (Setup)
    │
    ▼
Phase 2 (Foundational)
    │
    ▼
Phase 3 (US4 - Installation) ─── P1 ───┐
    │                                   │
    ▼                                   │
Phase 4 (US1 - Query) ─────── P1 MVP ──┤
    │                                   │
    ├─────────┬─────────────────────────┘
    ▼         ▼
Phase 5    Phase 6    Phase 7
(US2)      (US3)      (US5)
  P2         P2         P3
    │         │          │
    └────┬────┴──────────┘
         ▼
    Phase 8 (Polish)
```

### Within Each User Story

- JXA scripts before tool handlers
- Tool handlers before registry registration
- Core implementation before tests
- Tests verify each story independently

### Parallel Opportunities

**Phase 1 - Setup**:
```
T003 (Vapor dep) ║ T004 (folders) ║ T005 (entitlements) ║ T006 (icons) ║ T007 (strings)
```

**Phase 2 - Foundational**:
```
T008 (models) → T010 (bridge)
T009 (errors) ║ T011 (JXA templates)
T012 (protocol) → T013 (handler) → T014 (router) → T015 (server)
T016 (registry) ║ T017 (model tests) ║ T018 (protocol tests) ║ T019 (handler tests)
```

**Phase 3 - US4 (parallel views)**:
```
T023 (StatusIndicator) ║ T024 (MenuBarView) ║ T025 (SetupInstructions) ║ T026 (Preferences)
```

**Phase 4 - US1 (parallel JXA scripts)**:
```
T031-T035 all parallel (different scripts)
T036-T040 sequential (depend on scripts)
```

---

## Parallel Example: User Story 1

```bash
# Launch all JXA scripts for User Story 1 together:
Task: "T031 [US1] Implement JXA script for get_current_document"
Task: "T032 [US1] Implement JXA script for get_outline_structure"
Task: "T033 [US1] Implement JXA script for get_row"
Task: "T034 [US1] Implement JXA script for get_row_children"
Task: "T035 [US1] Implement JXA script for search_outline"

# Then tool handlers sequentially (depend on scripts):
Task: "T036 [US1] Implement get_current_document tool handler"
...
```

---

## Implementation Strategy

### MVP First (User Stories 4 + 1)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 4 (Installation) - app shell exists
4. Complete Phase 4: User Story 1 (Query) - core functionality
5. **STOP and VALIDATE**: Test querying with ChatGPT/Claude
6. Deploy/demo if ready - this is a functional MVP

### Incremental Delivery

1. Setup + Foundational + US4 + US1 → **MVP: Query-only release**
2. Add User Story 2 → **Add modification capabilities**
3. Add User Story 3 → **Add synthesis capabilities**
4. Add User Story 5 → **Add status visibility**
5. Polish → **Production-ready release**

### Suggested MVP Scope

**MVP = Phases 1-4 (Setup + Foundational + US4 + US1)**
- 43 tasks total for MVP
- Users can install app, query outlines, see setup instructions
- Modification and synthesis deferred to subsequent releases

---

## Task Summary

| Phase | User Story | Task Count | Complete | Priority |
|-------|-----------|------------|----------|----------|
| 1 | Setup | 7 | 7 | - |
| 2 | Foundational | 12 | 12 | - |
| 3 | US4 - Installation | 11 | 11 | P1 |
| 4 | US1 - Query | 13 | 13 | P1 (MVP) |
| 5 | US2 - Modify | 12 | 12 | P2 |
| 6 | US3 - Synthesis | 7 | 7 | P2 |
| 7 | US5 - Status | 7 | 7 | P3 |
| 8 | Polish | 10 | 2 | - |
| Post-MVP | Additions | 4 | 4 | - |
| **Total** | | **83** | **75** | |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- US6 (Full Content Partner) is DEFERRED per spec.md - not included in tasks
- All tasks follow constitution principles (security, simplicity, user-friendly errors)
