import Foundation

/// Helper class for localizing AI categories across different languages
struct LocalizedCategory {
    
    /// Get the display name for a category in the specified language
    static func getDisplayName(for category: String, language: SupportedLanguage) -> String {
        let categoryMappings = getCategoryMappings(for: language)
        return categoryMappings[category.lowercased()] ?? category.capitalized
    }
    
    /// Get all available categories for a language
    static func getAllCategories(for language: SupportedLanguage) -> [String: String] {
        return getCategoryMappings(for: language)
    }
    
    /// Get category icon emoji
    static func getIcon(for category: String) -> String {
        switch category.lowercased() {
        case "meeting", "toplantı", "réunion", "reunión":
            return "👥"
        case "idea", "fikir", "idée":
            return "💡"
        case "task", "todo", "yapılacak", "görev", "tâche", "tarea":
            return "✅"
        case "reminder", "hatırlatma", "rappel", "recordatorio":
            return "⏰"
        case "shopping", "alışveriş", "compras":
            return "🛒"
        case "movie", "film", "película":
            return "🎬"
        case "person", "kişi", "personne", "persona":
            return "👤"
        case "location", "konum", "lieu", "ubicación":
            return "📍"
        case "work", "iş", "travail", "trabajo":
            return "💼"
        case "personal", "kişisel", "personnel":
            return "🏠"
        case "health", "sağlık", "santé", "salud":
            return "🏥"
        case "travel", "seyahat", "voyage", "viaje":
            return "✈️"
        case "finance", "finans", "finanzas":
            return "💰"
        default:
            return "📝"
        }
    }
    
    /// Get category with icon for display
    static func getDisplayWithIcon(for category: String, language: SupportedLanguage) -> String {
        let icon = getIcon(for: category)
        let displayName = getDisplayName(for: category, language: language)
        return "\(icon) \(displayName)"
    }
    
    private static func getCategoryMappings(for language: SupportedLanguage) -> [String: String] {
        switch language {
        case .english:
            return [
                "meeting": "Meeting",
                "idea": "Idea",
                "task": "Task",
                "todo": "To-Do",
                "reminder": "Reminder",
                "shopping": "Shopping",
                "movie": "Movie",
                "person": "Person",
                "location": "Location",
                "work": "Work",
                "personal": "Personal",
                "health": "Health",
                "travel": "Travel",
                "finance": "Finance",
                "general": "General"
            ]
        case .turkish:
            return [
                "meeting": "Toplantı",
                "toplantı": "Toplantı",
                "idea": "Fikir",
                "fikir": "Fikir",
                "task": "Görev",
                "todo": "Yapılacak",
                "yapılacak": "Yapılacak",
                "görev": "Görev",
                "reminder": "Hatırlatma",
                "hatırlatma": "Hatırlatma",
                "shopping": "Alışveriş",
                "alışveriş": "Alışveriş",
                "movie": "Film",
                "film": "Film",
                "person": "Kişi",
                "kişi": "Kişi",
                "location": "Konum",
                "konum": "Konum",
                "work": "İş",
                "iş": "İş",
                "personal": "Kişisel",
                "kişisel": "Kişisel",
                "health": "Sağlık",
                "sağlık": "Sağlık",
                "travel": "Seyahat",
                "seyahat": "Seyahat",
                "finance": "Finans",
                "finans": "Finans",
                "general": "Genel",
                "genel": "Genel"
            ]
        case .spanish:
            return [
                "meeting": "Reunión",
                "reunión": "Reunión",
                "idea": "Idea",
                "task": "Tarea",
                "todo": "Pendiente",
                "tarea": "Tarea",
                "reminder": "Recordatorio",
                "recordatorio": "Recordatorio",
                "shopping": "Compras",
                "compras": "Compras",
                "movie": "Película",
                "película": "Película",
                "person": "Persona",
                "persona": "Persona",
                "location": "Ubicación",
                "ubicación": "Ubicación",
                "work": "Trabajo",
                "trabajo": "Trabajo",
                "personal": "Personal",
                "health": "Salud",
                "salud": "Salud",
                "travel": "Viaje",
                "viaje": "Viaje",
                "finance": "Finanzas",
                "finanzas": "Finanzas",
                "general": "General"
            ]
        case .french:
            return [
                "meeting": "Réunion",
                "réunion": "Réunion",
                "idea": "Idée",
                "idée": "Idée",
                "task": "Tâche",
                "todo": "À faire",
                "tâche": "Tâche",
                "reminder": "Rappel",
                "rappel": "Rappel",
                "shopping": "Shopping",
                "movie": "Film",
                "film": "Film",
                "person": "Personne",
                "personne": "Personne",
                "location": "Lieu",
                "lieu": "Lieu",
                "work": "Travail",
                "travail": "Travail",
                "personal": "Personnel",
                "personnel": "Personnel",
                "health": "Santé",
                "santé": "Santé",
                "travel": "Voyage",
                "voyage": "Voyage",
                "finance": "Finance",
                "general": "Général",
                "général": "Général"
            ]
        case .german:
            return [
                "meeting": "Meeting",
                "idea": "Idee",
                "idee": "Idee",
                "task": "Aufgabe",
                "todo": "Aufgabe",
                "aufgabe": "Aufgabe",
                "reminder": "Erinnerung",
                "erinnerung": "Erinnerung",
                "shopping": "Einkaufen",
                "einkaufen": "Einkaufen",
                "movie": "Film",
                "film": "Film",
                "person": "Person",
                "location": "Ort",
                "ort": "Ort",
                "work": "Arbeit",
                "arbeit": "Arbeit",
                "personal": "Persönlich",
                "persönlich": "Persönlich",
                "health": "Gesundheit",
                "gesundheit": "Gesundheit",
                "travel": "Reise",
                "reise": "Reise",
                "finance": "Finanzen",
                "finanzen": "Finanzen",
                "general": "Allgemein",
                "allgemein": "Allgemein"
            ]
        case .italian:
            return [
                "meeting": "Riunione",
                "riunione": "Riunione",
                "idea": "Idea",
                "task": "Compito",
                "todo": "Compito",
                "compito": "Compito",
                "reminder": "Promemoria",
                "promemoria": "Promemoria",
                "shopping": "Shopping",
                "movie": "Film",
                "film": "Film",
                "person": "Persona",
                "persona": "Persona",
                "location": "Luogo",
                "luogo": "Luogo",
                "work": "Lavoro",
                "lavoro": "Lavoro",
                "personal": "Personale",
                "personale": "Personale",
                "health": "Salute",
                "salute": "Salute",
                "travel": "Viaggio",
                "viaggio": "Viaggio",
                "finance": "Finanza",
                "finanza": "Finanza",
                "general": "Generale",
                "generale": "Generale"
            ]
        case .portuguese:
            return [
                "meeting": "Reunião",
                "reunião": "Reunião",
                "idea": "Ideia",
                "ideia": "Ideia",
                "task": "Tarefa",
                "todo": "Tarefa",
                "tarefa": "Tarefa",
                "reminder": "Lembrete",
                "lembrete": "Lembrete",
                "shopping": "Compras",
                "compras": "Compras",
                "movie": "Filme",
                "filme": "Filme",
                "person": "Pessoa",
                "pessoa": "Pessoa",
                "location": "Local",
                "local": "Local",
                "work": "Trabalho",
                "trabalho": "Trabalho",
                "personal": "Pessoal",
                "pessoal": "Pessoal",
                "health": "Saúde",
                "saúde": "Saúde",
                "travel": "Viagem",
                "viagem": "Viagem",
                "finance": "Finanças",
                "finanças": "Finanças",
                "general": "Geral",
                "geral": "Geral"
            ]
        case .japanese:
            return [
                "meeting": "会議",
                "会議": "会議",
                "idea": "アイデア",
                "アイデア": "アイデア",
                "task": "タスク",
                "todo": "やること",
                "タスク": "タスク",
                "reminder": "リマインダー",
                "リマインダー": "リマインダー",
                "shopping": "買い物",
                "買い物": "買い物",
                "movie": "映画",
                "映画": "映画",
                "person": "人",
                "人": "人",
                "location": "場所",
                "場所": "場所",
                "work": "仕事",
                "仕事": "仕事",
                "personal": "個人",
                "個人": "個人",
                "health": "健康",
                "健康": "健康",
                "travel": "旅行",
                "旅行": "旅行",
                "finance": "金融",
                "金融": "金融",
                "general": "一般",
                "一般": "一般"
            ]
        case .chinese:
            return [
                "meeting": "会议",
                "会议": "会议",
                "idea": "想法",
                "想法": "想法",
                "task": "任务",
                "todo": "待办",
                "任务": "任务",
                "reminder": "提醒",
                "提醒": "提醒",
                "shopping": "购物",
                "购物": "购物",
                "movie": "电影",
                "电影": "电影",
                "person": "人",
                "人": "人",
                "location": "位置",
                "位置": "位置",
                "work": "工作",
                "工作": "工作",
                "personal": "个人",
                "个人": "个人",
                "health": "健康",
                "健康": "健康",
                "travel": "旅行",
                "旅行": "旅行",
                "finance": "金融",
                "金融": "金融",
                "general": "一般",
                "一般": "一般"
            ]
        case .korean:
            return [
                "meeting": "회의",
                "회의": "회의",
                "idea": "아이디어",
                "아이디어": "아이디어",
                "task": "할일",
                "todo": "할일",
                "할일": "할일",
                "reminder": "알림",
                "알림": "알림",
                "shopping": "쇼핑",
                "쇼핑": "쇼핑",
                "movie": "영화",
                "영화": "영화",
                "person": "사람",
                "사람": "사람",
                "location": "위치",
                "위치": "위치",
                "work": "업무",
                "업무": "업무",
                "personal": "개인",
                "개인": "개인",
                "health": "건강",
                "건강": "건강",
                "travel": "여행",
                "여행": "여행",
                "finance": "금융",
                "금융": "금융",
                "general": "일반",
                "일반": "일반"
            ]
        case .russian:
            return [
                "meeting": "Встреча",
                "встреча": "Встреча",
                "idea": "Идея",
                "идея": "Идея",
                "task": "Задача",
                "todo": "Задача",
                "задача": "Задача",
                "reminder": "Напоминание",
                "напоминание": "Напоминание",
                "shopping": "Покупки",
                "покупки": "Покупки",
                "movie": "Фильм",
                "фильм": "Фильм",
                "person": "Человек",
                "человек": "Человек",
                "location": "Место",
                "место": "Место",
                "work": "Работа",
                "работа": "Работа",
                "personal": "Личное",
                "личное": "Личное",
                "health": "Здоровье",
                "здоровье": "Здоровье",
                "travel": "Путешествие",
                "путешествие": "Путешествие",
                "finance": "Финансы",
                "финансы": "Финансы",
                "general": "Общее",
                "общее": "Общее"
            ]
        }
    }
}