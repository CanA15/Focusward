import CoreGraphics

enum NotchLayout {
    static let expandedMinimumWidth: CGFloat = 380
    static let rowHeight: CGFloat = 52
    static let footerHeight: CGFloat = 36
    // The expanded shape curves out into the top edge of the screen, as the notch does.
    static let shoulderRadius: CGFloat = 10
    // The expanded content uses these insets, and the expanded height includes them.
    static let horizontalInset: CGFloat = shoulderRadius + 16
    static let bottomInset: CGFloat = 8

    // macOS reports the menu bar areas on each side of the notch. The notch is the gap between them.
    static func notchFrame(
        screenFrame: CGRect,
        topInset: CGFloat,
        leftAreaWidth: CGFloat?,
        rightAreaWidth: CGFloat?
    ) -> CGRect? {
        guard topInset > 0, let leftAreaWidth, let rightAreaWidth else { return nil }
        let width = screenFrame.width - leftAreaWidth - rightAreaWidth
        guard width > 0 else { return nil }

        return CGRect(
            x: screenFrame.minX + leftAreaWidth,
            y: screenFrame.maxY - topInset,
            width: width,
            height: topInset
        )
    }

    static func expandedFrame(notch: CGRect, breakCount: Int) -> CGRect {
        let width = max(notch.width + 2 * shoulderRadius, expandedMinimumWidth)
        let height = notch.height + CGFloat(breakCount) * rowHeight + footerHeight + bottomInset
        return CGRect(
            x: notch.midX - width / 2,
            y: notch.maxY - height,
            width: width,
            height: height
        )
    }
}
