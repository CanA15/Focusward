import CoreGraphics

enum NotchLayout {
    static let expandedMinimumWidth: CGFloat = 340
    static let rowHeight: CGFloat = 32
    static let padding: CGFloat = 12

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

    // The collapsed panel covers only the notch, where the display has no pixels.
    static func panelFrame(notch: CGRect, isExpanded: Bool, rowCount: Int) -> CGRect {
        guard isExpanded else { return notch }

        let width = max(notch.width, expandedMinimumWidth)
        let height = notch.height + CGFloat(rowCount) * rowHeight + padding
        return CGRect(
            x: notch.midX - width / 2,
            y: notch.maxY - height,
            width: width,
            height: height
        )
    }
}
