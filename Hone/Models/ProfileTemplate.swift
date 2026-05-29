import Foundation

struct ProfileTemplate: Identifiable, Equatable {
    let id: UUID
    let name: String
    let tagline: String
    let prompt: String
    let icon: String

    static func == (lhs: ProfileTemplate, rhs: ProfileTemplate) -> Bool { lhs.id == rhs.id }

    static let brevity = ProfileTemplate(
        id: UUID(uuidString: "A0000001-0000-0000-0000-000000000001")!,
        name: "Brevity",
        tagline: "Cut the fluff. Keep the point.",
        prompt: "Rewrite the selected text to be as short as possible without losing meaning.\n\n- Lead with the single most important thing.\n- Cut every word that doesn't earn its place.\n- One idea per sentence. Split competing clauses.\n- Strong, specific verbs. Remove: \"there is,\" \"I just wanted to,\" \"it is important to note.\"\n- No filler: \"As mentioned,\" \"Hope this helps,\" \"Just following up.\"\n- Use bullets for lists — never bury them in paragraphs.\n- No passive voice.\n- No em dashes — use commas or periods instead.\n\nOutput only the rewritten text. No commentary.",
        icon: "scissors"
    )

    static let casualSlack = ProfileTemplate(
        id: UUID(uuidString: "A0000002-0000-0000-0000-000000000002")!,
        name: "Casual Slack",
        tagline: "Warm, fast, teammate energy.",
        prompt: "Rewrite as a casual, warm internal Slack message.\n\n- Skip formal greetings. Just dive in.\n- Use contractions: gonna, wanna, kinda, y'all.\n- Lead with the main point. Keep it short.\n- Add an emoji where it fits naturally.\n- No corporate filler: no \"circling back,\" \"per my last message,\" \"touching base.\"\n- No formal sign-offs.\n- No em dashes — use commas or periods.\n\nOutput only the rewritten text. No commentary.",
        icon: "bubble.left.and.bubble.right.fill"
    )

    static let customerReply = ProfileTemplate(
        id: UUID(uuidString: "A0000003-0000-0000-0000-000000000003")!,
        name: "Customer Reply",
        tagline: "Professional, clear, and warm.",
        prompt: "Rewrite as a professional customer support reply.\n\n- Acknowledge the customer's issue in the first sentence.\n- State the solution or next step clearly.\n- Be warm but not over-the-top.\n- No jargon unless necessary.\n- No filler: \"Hope this finds you well,\" \"Please don't hesitate.\"\n- No passive voice.\n- Under 4 sentences unless complexity requires more.\n\nOutput only the rewritten text. No commentary.",
        icon: "envelope.fill"
    )

    static let executive = ProfileTemplate(
        id: UUID(uuidString: "A0000004-0000-0000-0000-000000000004")!,
        name: "Executive",
        tagline: "Structured for leadership.",
        prompt: "Rewrite as a concise executive summary.\n\n- Lead with the outcome or recommendation.\n- Use bullets for supporting points.\n- State facts and implications, not opinions.\n- No filler language.\n- Formal but not stiff.\n- Bold the most critical information.\n\nOutput only the rewritten text. No commentary.",
        icon: "doc.text.fill"
    )

    static let custom = ProfileTemplate(
        id: UUID(uuidString: "A0000005-0000-0000-0000-000000000005")!,
        name: "Custom",
        tagline: "Write your own instructions.",
        prompt: "",
        icon: "sparkles"
    )

    static let all: [ProfileTemplate] = [.brevity, .casualSlack, .customerReply, .executive, .custom]
}
