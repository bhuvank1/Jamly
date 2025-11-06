//
//  SettingOption.swift
//  Jamly
//
//  Created by Ajisegiri, Fareedah I on 11/4/25.
//

enum SettingType {
    case navigation
    case toggle
    case action
}

struct SettingOption {
    let title: String
    let type: SettingType
}
