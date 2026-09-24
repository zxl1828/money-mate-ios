import Foundation

/// 两级分类：大类 → 细分（与安卓 `category_tree.dart` 一一对应）。
/// 记账页默认只显示大类，点大类就地展开细分，界面干净但记账粒度够细。
enum CategoryTree {
    static let expenseTree: [(String, [String])] = [
        ("餐饮", ["早餐", "午餐", "晚餐", "外卖", "零食", "饮料"]),
        ("交通", ["公交地铁", "打车", "加油", "停车", "火车飞机"]),
        ("购物", ["超市", "日用品", "服饰", "数码", "美妆"]),
        ("居住", ["房租", "水电燃气", "物业", "家居", "维修"]),
        ("娱乐", ["电影", "游戏", "聚会", "运动", "旅行"]),
        ("医疗", ["门诊", "药品", "体检", "牙科"]),
        ("学习", ["课程", "书籍", "考试", "文具"]),
        ("人情", ["红包", "礼物", "请客", "份子钱"]),
        ("通讯", ["话费", "流量", "宽带"]),
        ("宠物", ["宠物食品", "宠物医疗", "宠物用品"]),
        ("其他", ["其他支出"])
    ]

    static let incomeTree: [(String, [String])] = [
        ("工资", ["基本工资", "绩效奖金", "加班费", "补贴"]),
        ("理财", ["利息", "基金分红", "股票收益", "其他理财"]),
        ("其他收入", ["红包", "报销", "退款", "兼职", "其他"])
    ]

    /// 大类列表（保持顺序）
    static func parents(income: Bool) -> [String] {
        (income ? incomeTree : expenseTree).map(\.0)
    }

    /// 某个大类下的细分（不含大类本身）
    static func children(of parent: String) -> [String] {
        (expenseTree + incomeTree).first { $0.0 == parent }?.1 ?? []
    }

    /// 归到大类：细分或大类都返回大类名（找不到原样返回），用于图标/配色兜底。
    static func root(of name: String) -> String {
        for (parent, children) in expenseTree + incomeTree where children.contains(name) {
            return parent
        }
        return name
    }
}
