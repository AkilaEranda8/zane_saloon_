# ─────────────────────────────────────────────────────────────────────────────
# Salon-specific training phrases for intent classification
# Add more phrases to improve accuracy
# ─────────────────────────────────────────────────────────────────────────────

TRAINING_DATA = {
    "greet": [
        "hello", "hi", "hey", "good morning", "good afternoon", "good evening",
        "hi there", "hello there", "ayubowan", "kohomada", "hello bot",
        "hai", "hii", "heyyy", "yo", "sup", "whats up", "what's up",
        "oba kohomada", "machan", "bro", "hola",
    ],

    "book_appointment": [
        "i want to book", "book appointment", "make appointment",
        "schedule appointment", "i need a booking", "can i book",
        "appointment book karanna", "apointment onei", "book karanna",
        "i want to schedule", "reserve a slot", "get an appointment",
        "appointment hadanna", "appoint karanna", "book a slot",
        "can you book for me", "set an appointment", "i'd like to book",
        "make a reservation", "i want a haircut appointment",
        "appointment ganna", "appoint onei", "book one for me",
        "i want to come in", "want to visit", "coming in for service",
    ],

    "check_services": [
        "what services", "list services", "what do you offer",
        "services list", "show services", "what treatments",
        "monawada karanne", "services monawada", "what can i get",
        "what do you have", "available services", "service katharaya",
        "tell me about services", "services danna", "what are your services",
        "what treatments do you have", "show me what you offer",
        "services show karanna", "service list eka denna",
    ],

    "check_prices": [
        "how much", "price", "cost", "rate", "charges", "fee",
        "how much does it cost", "what is the price", "pricing",
        "kiyadha", "gana kiya", "price kiyada", "cost kiyada",
        "how much for", "what does it cost", "how much is a",
        "price list", "price chart", "rate card", "service charges",
        "how much is haircut", "facial price", "how much is coloring",
        "eka kiyadha", "gana mokakda",
    ],

    "check_availability": [
        "is available", "check availability", "any slots",
        "available time", "free slot", "when can i come",
        "available date", "available nisa", "slot thiyanawada",
        "is there a slot", "when is free", "any opening",
        "can i come tomorrow", "time slot", "opening available",
        "check slot", "available appointment", "free time",
        "koheda free", "koheda available", "opening innawada",
    ],

    "check_branches": [
        "where are you", "location", "branch", "address",
        "where is the salon", "which branch", "branches",
        "where located", "salon location", "find you",
        "koheda inne", "address danna", "location danna",
        "how many branches", "branch list", "where to find",
        "directions", "how to get there", "map",
    ],

    "check_staff": [
        "who is available", "staff", "stylist", "hairdresser",
        "who can i see", "available staff", "who works there",
        "staff list", "who are the stylists", "any good stylist",
        "staff thiyanawada", "stylist innawada", "who is working",
        "recommended staff", "best stylist", "who should i book",
        "staff danna", "people working", "team",
    ],

    "cancel_appointment": [
        "cancel appointment", "cancel booking", "i want to cancel",
        "remove my appointment", "delete booking", "cancel my slot",
        "appointment cancel karanna", "cancel karanna", "nothung",
        "i need to cancel", "please cancel", "cancel it",
        "don't want appointment", "cancel the booking",
    ],

    "goodbye": [
        "bye", "goodbye", "see you", "thanks bye", "ok thanks",
        "thank you bye", "later", "cya", "take care", "done",
        "ok done", "that's all", "nothing else", "thats it",
        "thank you", "thanks", "ok thank you", "cheers",
        "istuti", "bohoma istuti", "gihin ennam", "ok gihin ennam",
    ],

    "help": [
        "help", "what can you do", "how does this work",
        "i need help", "assist me", "guide me", "confused",
        "what to do", "options", "menu", "commands",
        "help karanna", "help eka denna", "explain",
        "how to use", "what can i ask", "what do you know",
    ],
}
