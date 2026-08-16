/// Mirrors the `@selected` hash shapes returned by TrySelector#run.
public enum TUIAction: Equatable {
    case cd(path: String)
    case mkdir(path: String)
    case rename(basePath: String, old: String, new: String)
    case ascend(source: String, dest: String, basename: String, basePath: String)
    case delete(paths: [(path: String, basename: String)], basePath: String)
    case cancel

    public static func == (lhs: TUIAction, rhs: TUIAction) -> Bool {
        switch (lhs, rhs) {
        case (.cd(let a), .cd(let b)): return a == b
        case (.mkdir(let a), .mkdir(let b)): return a == b
        case (.rename(let ab, let ao, let an), .rename(let bb, let bo, let bn)):
            return ab == bb && ao == bo && an == bn
        case (.ascend(let asrc, let ad, let abn, let abp), .ascend(let bsrc, let bd, let bbn, let bbp)):
            return asrc == bsrc && ad == bd && abn == bbn && abp == bbp
        case (.delete(let ap, let abp), .delete(let bp, let bbp)):
            return abp == bbp && ap.count == bp.count
                && zip(ap, bp).allSatisfy { $0.path == $1.path && $0.basename == $1.basename }
        case (.cancel, .cancel): return true
        default: return false
        }
    }
}
