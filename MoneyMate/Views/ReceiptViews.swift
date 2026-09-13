import SwiftUI
import PhotosUI

/// 收据 / 发票：选择、缩略图、删除
struct AttachmentEditor: View {
    @Binding var attachments: [TxAttachment]

    @State private var items: [PhotosPickerItem] = []
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if attachments.isEmpty && !loading {
                PhotosPicker(selection: $items, maxSelectionCount: 4, matching: .images) {
                    VStack(spacing: 6) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18, weight: .semibold))
                        Text("添加收据 / 发票照片")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(Palette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.4, dash: [6, 5]))
                            .foregroundStyle(Palette.primary.opacity(0.45))
                    )
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(attachments) { item in
                            thumbnail(item)
                        }
                        PhotosPicker(selection: $items, maxSelectionCount: 4, matching: .images) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Palette.primary)
                                .frame(width: 66, height: 66)
                                .background(Palette.primary.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                        }
                        if loading { ProgressView().frame(width: 40, height: 66) }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .onChange(of: items) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task { await ingest(newValue) }
        }
    }

    private func thumbnail(_ item: TxAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            if let image = AttachmentStore.loadImage(item) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 66, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            } else {
                Image(systemName: "doc.fill")
                    .frame(width: 66, height: 66)
                    .foregroundStyle(Palette.ink.opacity(0.5))
                    .background(Palette.primary.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            }
            Button {
                AttachmentStore.delete(item)
                attachments.removeAll { $0.id == item.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.white, Palette.rose)
            }
            .buttonStyle(.plain)
            .offset(x: 5, y: -5)
        }
    }

    private func ingest(_ picked: [PhotosPickerItem]) async {
        loading = true
        for item in picked {
            if let data = try? await item.loadTransferable(type: Data.self),
               let attachment = AttachmentStore.save(data: data, isImage: true) {
                attachments.append(attachment)
            }
        }
        loading = false
        items = []
    }
}

/// 只读附件画廊（详情页用）
struct AttachmentGallery: View {
    let attachments: [TxAttachment]
    var onDelete: ((TxAttachment) -> Void)? = nil

    @State private var preview: TxAttachment?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachments) { item in
                    ZStack(alignment: .topTrailing) {
                        Button {
                            preview = item
                        } label: {
                            if let image = AttachmentStore.loadImage(item) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                            } else {
                                Image(systemName: "doc.fill")
                                    .frame(width: 84, height: 84)
                                    .foregroundStyle(Palette.ink.opacity(0.5))
                                    .background(Palette.primary.opacity(0.10),
                                                in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                            }
                        }
                        .buttonStyle(.plain)

                        if let onDelete {
                            Button {
                                AttachmentStore.delete(item)
                                onDelete(item)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white, Palette.rose)
                            }
                            .buttonStyle(.plain)
                            .offset(x: 5, y: -5)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .fullScreenCover(item: $preview) { item in
            AttachmentPreview(item: item)
        }
    }
}

// MARK: - 全屏查看

struct AttachmentPreview: View {
    let item: TxAttachment
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let image = AttachmentStore.loadImage(item) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in scale = min(max(lastScale * value, 1), 6) }
                                .onEnded { _ in lastScale = scale },
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height)
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                    )
            } else {
                Text("图片已丢失")
                    .foregroundStyle(.white.opacity(0.8))
            }
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(18)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }
}
