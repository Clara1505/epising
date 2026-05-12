//
//  SupabaseClient.swift
//  epising
//
//  Created by Clara Sion Saunier on 12/05/2026.
//

import Foundation
import Supabase

// Point d'entrée unique vers Supabase — partagé dans toute l'app
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://pzvrvfdwygvpelfvceyv.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6dnJ2ZmR3eWd2cGVsZnZjZXl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcwMzA0NjUsImV4cCI6MjA5MjYwNjQ2NX0.0PqXL-UdHlizNAdLrZuiWlilJXand49WIT9zQtIIoso"
)
