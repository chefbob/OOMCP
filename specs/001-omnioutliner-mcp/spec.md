# Feature Specification: OmniOutliner MCP Server

**Feature Branch**: `001-omnioutliner-mcp`
**Created**: 2026-01-13
**Status**: Draft

## Clarifications

### Session 2026-01-13

- Q: What scope of AI content synthesis should be included? → A: Option B (Query + Assisted Synthesis) for initial release; Option C (Full Content Partner) deferred as future user story
- Q: Should modifications require explicit user confirmation? → A: Confirm destructive only (deletions and bulk changes require confirmation; simple adds/edits execute immediately with notification)
- Q: Should AI synthesis work across multiple documents? → A: Cross-document when requested (default to current document; user can explicitly request analysis across multiple or all open documents)
- Q: How should ambiguous references (multiple matches) be handled? → A: Ask for clarification (present matching items and ask user to specify which one they mean)
- Q: Should users be able to undo AI-made changes? → A: Rely on OmniOutliner's native undo (Cmd+Z); inform users that changes can be undone in the app
- Q: Which AI clients should be supported? → A: Both ChatGPT Desktop (primary) and Claude Desktop. Native macOS menu bar app with HTTP-only transport (works for both clients).

**Input**: User description: "Create an MCP server that runs on a local machine. It will connect a local AI agent to OmniOutline and allow a user to ask questions of data in OmniOutline. It will optionally allow the user to make changes to data in OmniOutline. The users will not be technical. We will need a straightforward way to install and run the mcp. The target platform is MacOS."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Query Outline Content (Priority: P1)

As a non-technical user, I want to ask questions about my OmniOutliner documents so that I can quickly find information, get summaries, and understand my data without manually searching through complex outlines.

**Why this priority**: This is the core value proposition - allowing users to conversationally query their outline data. Without this capability, the MCP server has no purpose. Most users will primarily want to read and understand their data before making changes.

**Independent Test**: Can be fully tested by opening an OmniOutliner document and asking the AI agent questions like "What are the main topics in this outline?" or "Summarize the section about project milestones" and receiving accurate responses.

**Acceptance Scenarios**:

1. **Given** an OmniOutliner document is open, **When** the user asks "What is this document about?", **Then** the AI agent provides a summary of the document's main topics and structure
2. **Given** an OmniOutliner document with hierarchical content, **When** the user asks "List all items under [specific section]", **Then** the AI agent returns the nested items from that section
3. **Given** an OmniOutliner document with notes attached to rows, **When** the user asks about a specific row's details, **Then** the AI agent includes the note content in its response
4. **Given** multiple OmniOutliner documents are open, **When** the user asks about a specific document by name, **Then** the AI agent queries only that document

---

### User Story 2 - Modify Outline Content (Priority: P2)

As a non-technical user, I want to make changes to my OmniOutliner documents through natural language commands so that I can add, edit, or reorganize content without manually navigating the interface.

**Why this priority**: Modification capability adds significant value but is secondary to querying. Users need to understand their data before modifying it. This feature requires the query capability to work effectively (to identify what to modify).

**Independent Test**: Can be fully tested by asking the AI agent to "Add a new item called 'Review meeting notes' under the Tasks section" and verifying the item appears in OmniOutliner.

**Acceptance Scenarios**:

1. **Given** an OmniOutliner document is open, **When** the user requests "Add a new row called [text] under [section]", **Then** a new row with that text is created in the specified location
2. **Given** an existing row in the outline, **When** the user requests "Change [row text] to [new text]", **Then** the row text is updated accordingly
3. **Given** a row with a note, **When** the user requests "Add a note to [row] saying [text]", **Then** the note is added or updated on that row
4. **Given** an existing row, **When** the user requests "Move [row] under [different section]", **Then** the row is relocated to the new parent
5. **Given** a non-destructive modification request (add, edit, move), **When** the AI agent executes the change, **Then** the user is notified of what was changed after execution
6. **Given** a destructive modification request (delete, bulk changes), **When** the AI agent is about to execute, **Then** the user must explicitly confirm before the action proceeds
7. **Given** any modification has been made by the AI, **When** the user wants to undo it, **Then** they can use OmniOutliner's native undo (Cmd+Z) and the system informs them of this capability

---

### User Story 3 - AI-Assisted Content Synthesis (Priority: P2)

As a non-technical user, I want the AI to help me synthesize, organize, and develop content based on my outline data so that I can gain insights, create summaries, and draft new content without manually compiling information.

**Why this priority**: This extends the core query capability to provide higher-value AI assistance. Users who can query their data will naturally want help making sense of it and developing new content from it.

**Independent Test**: Can be fully tested by asking the AI agent to "Summarize the key points from the Project Status section" or "Draft an executive summary based on this outline" and receiving coherent, accurate synthesized content.

**Acceptance Scenarios**:

1. **Given** an OmniOutliner document with multiple sections, **When** the user asks "Summarize this document", **Then** the AI provides a coherent summary capturing the main points and structure
2. **Given** an outline with detailed content, **When** the user asks "What are the key themes across all sections?", **Then** the AI identifies and lists recurring themes or patterns
3. **Given** a section with bullet points, **When** the user asks "Turn these points into a paragraph", **Then** the AI drafts prose content based on the outline items
4. **Given** an outline structure, **When** the user asks "Suggest how to reorganize this for clarity", **Then** the AI provides specific reorganization recommendations
5. **Given** existing outline content, **When** the user asks "Draft a [document type] based on this outline", **Then** the AI generates appropriate draft content using the outline as source material
6. **Given** multiple OmniOutliner documents are open, **When** the user asks "Compare the tasks across all my open documents", **Then** the AI analyzes content from all open documents and provides a cross-document synthesis
7. **Given** multiple documents are open, **When** the user asks a synthesis question without specifying scope, **Then** the AI defaults to the current/frontmost document

---

### User Story 4 - Simple Installation and Startup (Priority: P1)

As a non-technical macOS user, I want to install and run the MCP server with minimal effort so that I can start using AI with my OmniOutliner documents without technical knowledge.

**Why this priority**: Tied for P1 because without easy installation, non-technical users cannot access any functionality. The simplicity requirement is core to the target audience.

**Independent Test**: Can be fully tested by having a non-technical user follow the installation instructions and successfully connect their AI agent to OmniOutliner within 10 minutes.

**Acceptance Scenarios**:

1. **Given** a macOS computer with OmniOutliner installed, **When** the user follows the installation guide, **Then** the MCP server is installed in under 5 minutes
2. **Given** the MCP server is installed, **When** the user starts the server, **Then** it connects to OmniOutliner automatically
3. **Given** the server is running, **When** OmniOutliner is not running, **Then** the server provides a clear message indicating OmniOutliner needs to be opened
4. **Given** the server encounters an error, **When** displaying the error to the user, **Then** the message is in plain language with suggested next steps

---

### User Story 5 - Connection Status Visibility (Priority: P3)

As a non-technical user, I want to know whether the MCP server is connected and working so that I can trust that my queries will work.

**Why this priority**: While important for user confidence, this is a supporting feature. Users can still use the system without status visibility; they'll simply notice if queries fail.

**Independent Test**: Can be fully tested by starting the server and observing clear visual or textual indication of connection status.

**Acceptance Scenarios**:

1. **Given** the MCP server is starting, **When** it successfully connects to OmniOutliner, **Then** a success message is displayed
2. **Given** OmniOutliner closes while the server is running, **When** the connection is lost, **Then** the user is notified and informed how to reconnect

---

### User Story 6 - Full Content Partner (Priority: DEFERRED)

As a non-technical user, I want the AI to proactively suggest improvements, identify content gaps, generate related content, and provide ongoing writing assistance so that I have a collaborative partner for content development.

**Why this priority**: DEFERRED - This represents an advanced capability that builds on the assisted synthesis features. Decision to implement will be made after initial release based on user feedback and adoption of synthesis features.

**Independent Test**: Would be tested by having the AI proactively identify missing sections, suggest additional content, or offer unsolicited improvements during user sessions.

**Acceptance Scenarios** (preliminary):

1. **Given** an outline being edited, **When** the AI detects potential gaps or inconsistencies, **Then** it proactively suggests additions or corrections
2. **Given** a partial outline, **When** the user is working on a section, **Then** the AI offers contextually relevant content suggestions
3. **Given** user-generated content, **When** the AI identifies improvement opportunities, **Then** it offers specific writing enhancements

---

### Edge Cases

- What happens when OmniOutliner is not installed on the system?
- How does the system handle when no documents are currently open in OmniOutliner?
- What happens when the user references a section or row that doesn't exist?
- How does the system handle very large outlines with thousands of rows?
- What happens if the user's query is ambiguous (multiple rows match)? → System presents matching items and asks user to clarify which one they mean
- How does the system handle locked or read-only documents when modification is requested?
- What happens when OmniOutliner crashes or is force-quit while the MCP server is running?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST be able to read the content of open OmniOutliner documents including row text, hierarchy, and notes
- **FR-002**: System MUST be able to list all currently open OmniOutliner documents
- **FR-003**: System MUST be able to search for specific text within an outline
- **FR-004**: System MUST be able to navigate the hierarchical structure of outlines (parent/child relationships)
- **FR-005**: System MUST be able to retrieve metadata about rows (status checkboxes, custom columns if present)
- **FR-006**: System MUST be able to add new rows to a specified location in the outline
- **FR-007**: System MUST be able to modify existing row text and notes
- **FR-008**: System MUST be able to move rows to different locations within the outline
- **FR-009**: System MUST be able to delete rows from the outline
- **FR-009a**: System MUST require explicit user confirmation before executing destructive operations (deletions, bulk changes)
- **FR-009b**: System MUST notify users of completed non-destructive modifications (adds, edits, moves) after execution
- **FR-009c**: System MUST inform users that changes can be undone using OmniOutliner's native undo (Cmd+Z)
- **FR-010**: System MUST provide clear error messages in non-technical language when operations fail
- **FR-010a**: System MUST present matching items for user disambiguation when a reference matches multiple rows or sections
- **FR-011**: System MUST run entirely on the local macOS machine without requiring internet connectivity for core functionality
- **FR-012**: System MUST provide a single-step or minimal-step installation process suitable for non-technical users
- **FR-013**: System MUST provide a simple way to start and stop the server
- **FR-014**: System MUST communicate with OmniOutliner using macOS automation capabilities (AppleScript/JavaScript for Automation)
- **FR-015**: System MUST conform to the Model Context Protocol (MCP) specification to enable AI agent integration
- **FR-016**: System MUST provide outline content in a format suitable for AI summarization and synthesis
- **FR-017**: System MUST support retrieval of content from multiple open documents when explicitly requested by the user, defaulting to the current document when scope is unspecified
- **FR-018**: System MUST be able to insert AI-generated content (summaries, drafts) into specified locations in the outline

### Key Entities

- **Document**: An OmniOutliner document currently open in the application; has a name, file path, and contains rows
- **Row**: A single item in an outline; has text content, optional note, hierarchical position (parent/children), and optional status/metadata
- **Outline Structure**: The hierarchical tree of rows within a document; defines parent-child relationships and ordering
- **Connection**: The active link between the MCP server and OmniOutliner; has a status (connected/disconnected) and enables all document operations

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Non-technical users can complete installation and first successful query within 10 minutes
- **SC-002**: Users can retrieve information from their outlines with 95% accuracy (correct content returned for well-formed queries)
- **SC-003**: Document modifications complete within 2 seconds of user request
- **SC-004**: System handles outlines with up to 5,000 rows without noticeable performance degradation
- **SC-005**: 90% of users can successfully install and use the system without requiring technical support
- **SC-006**: Error messages are understandable to non-technical users (validated by user testing)
- **SC-007**: Server startup completes within 5 seconds on standard macOS hardware

## Assumptions

- Users have OmniOutliner 5 Pro or later installed on their macOS system (Pro version required - scripting is a Pro-only feature)
- Users have macOS 13 (Ventura) or later
- Users have an AI agent/client that supports the MCP protocol:
  - ChatGPT Desktop with Developer Mode access (primary target), OR
  - Claude Desktop
- OmniOutliner's AppleScript/JXA automation support remains available and stable
- Users grant necessary macOS automation permissions when prompted
- The application runs as a native macOS menu bar app (not a CLI tool)
- Users can install DMG applications (drag to Applications folder)
- ChatGPT Desktop users can access Developer Mode (Business/Enterprise/Education/Pro/Plus plans)
