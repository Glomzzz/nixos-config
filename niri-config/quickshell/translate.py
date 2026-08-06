import xml.etree.ElementTree as ET

translations_en = {
    "空气质量": "AQI",
    "日出日落": "Sun",
    "月相": "Moon",
    "优": "Excellent",
    "良": "Good",
    "轻度污染": "Lightly Polluted",
    "中度污染": "Moderately Polluted",
    "重度污染": "Heavily Polluted",
    "严重污染": "Severely Polluted",
    "新月": "New Moon",
    "蛾眉月": "Waxing Crescent",
    "上弦月": "First Quarter",
    "盈凸月": "Waxing Gibbous",
    "满月": "Full Moon",
    "亏凸月": "Waning Gibbous",
    "下弦月": "Last Quarter",
    "残月": "Waning Crescent",
    "紫外线": "UV Index",
    "体感温度": "Feels Like",
    "湿度": "Humidity",
    "风速": "Wind",
    "气压": "Pressure",
    "能见度": "Visibility",
    "照亮 ": "Illumination "
}

translations_tw = {
    "空气质量": "空氣品質",
    "日出日落": "日出日落",
    "月相": "月相",
    "优": "優",
    "良": "良",
    "轻度污染": "輕度污染",
    "中度污染": "中度污染",
    "重度污染": "重度污染",
    "严重污染": "嚴重污染",
    "新月": "新月",
    "蛾眉月": "蛾眉月",
    "上弦月": "上弦月",
    "盈凸月": "盈凸月",
    "满月": "滿月",
    "亏凸月": "虧凸月",
    "下弦月": "下弦月",
    "残月": "殘月",
    "紫外线": "紫外線",
    "体感温度": "體感溫度",
    "湿度": "濕度",
    "风速": "風速",
    "气压": "氣壓",
    "能见度": "能見度",
    "照亮 ": "照亮 "
}

def update_ts(filepath, trans_dict):
    tree = ET.parse(filepath)
    root = tree.getroot()
    for context in root.findall('context'):
        for message in context.findall('message'):
            source = message.find('source')
            if source is not None and source.text in trans_dict:
                translation = message.find('translation')
                if translation is not None:
                    translation.text = trans_dict[source.text]
                    if 'type' in translation.attrib:
                        del translation.attrib['type']
    tree.write(filepath, encoding="utf-8", xml_declaration=True)

update_ts('i18n/clavis_en_US.ts', translations_en)
update_ts('i18n/clavis_zh_TW.ts', translations_tw)

# For zh_CN, we just set the translation equal to the source
tree = ET.parse('i18n/clavis_zh_CN.ts')
root = tree.getroot()
for context in root.findall('context'):
    for message in context.findall('message'):
        source = message.find('source')
        if source is not None and source.text in translations_en: # just checking if it's one of our strings
            translation = message.find('translation')
            if translation is not None:
                translation.text = source.text
                if 'type' in translation.attrib:
                    del translation.attrib['type']
tree.write('i18n/clavis_zh_CN.ts', encoding="utf-8", xml_declaration=True)
print("Translations updated")
