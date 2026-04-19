import UniformTypeIdentifiers

extension UTType {
    static var comicImportTypes: [UTType] {
        var types: [UTType] = [.folder, .pdf]
        let extensions = [
            "cbz", "zip", "cbr", "rar",
            "jpg", "jpeg", "png", "webp", "heic", "heif", "gif", "bmp", "tif", "tiff"
        ]

        for fileExtension in extensions {
            if let type = UTType(filenameExtension: fileExtension) {
                types.append(type)
            }
        }

        return types
    }

    static func comicFormat(for url: URL) -> ComicFormat? {
        if url.hasDirectoryPath {
            return .folder
        }

        switch url.pathExtension.lowercased() {
        case "cbz":
            return .cbz
        case "zip":
            return .zip
        case "cbr":
            return .cbr
        case "rar":
            return .rar
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "webp", "heic", "heif", "gif", "bmp", "tif", "tiff":
            return .image
        default:
            return nil
        }
    }
}
