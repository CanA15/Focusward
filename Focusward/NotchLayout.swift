import CoreGraphics

enum NotchLayout {
    static let earWidth: CGFloat = 64
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

    static func panelFrame(notch: CGRect, isExpanded: Bool, rowCount: Int) -> CGRect {
        let collapsedWidth = notch.width + 2 * earWidth
        let size = isExpanded
            ? CGSize(
                width: max(collapsedWidth, expandedMinimumWidth),
                height: notch.height + CGFloat(rowCount) * rowHeight + 2 * padding
            )
            : CGSize(width: collapsedWidth, height: notch.height)

        return CGRect(
            x: notch.midX - size.width / 2,
            y: notch.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }
}
