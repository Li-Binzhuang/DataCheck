#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将CSV测试用例转换为XMind格式
"""

import csv
import zipfile
import os
from datetime import datetime

def generate_topic_id(index):
    """生成topic ID"""
    return f"topic_{index}_{datetime.now().timestamp()}"

def create_xmind_content(csv_file):
    """读取CSV并生成XMind content.xml"""
    
    # 读取CSV文件
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    # 按用例目录分组
    grouped_data = {}
    for row in rows:
        directory = row['用例目录']
        if directory not in grouped_data:
            grouped_data[directory] = []
        grouped_data[directory].append(row)
    
    # 生成XML内容
    timestamp = str(int(datetime.now().timestamp() * 1000))
    
    xml_content = f'''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xmap-content xmlns="urn:xmind:xmap:xmlns:content:2.0" xmlns:fo="http://www.w3.org/1999/XSL/Format" xmlns:svg="http://www.w3.org/2000/svg" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:xlink="http://www.w3.org/1999/xlink" modified-by="kiro" timestamp="{timestamp}" version="2.0">
<sheet id="sheet_root" modified-by="kiro" timestamp="{timestamp}">
<topic id="root_topic" modified-by="kiro" structure-class="org.xmind.ui.map.unbalanced" timestamp="{timestamp}">
<title>特征平台测试用例</title>
<children>
<topics type="attached">
'''
    
    topic_index = 0
    
    # 遍历每个目录
    for directory, cases in grouped_data.items():
        topic_index += 1
        dir_id = generate_topic_id(topic_index)
        
        # 解析目录层级
        dir_parts = directory.split('~')
        dir_name = dir_parts[-1] if dir_parts else directory
        
        xml_content += f'''<topic id="{dir_id}" modified-by="kiro" timestamp="{timestamp}">
<title>{dir_name}</title>
<children>
<topics type="attached">
'''
        
        # 添加该目录下的所有用例
        for case in cases:
            topic_index += 1
            case_id = generate_topic_id(topic_index)
            case_name = case['用例名称']
            
            xml_content += f'''<topic id="{case_id}" modified-by="kiro" timestamp="{timestamp}">
<title>{case_name}</title>
'''
            
            # 添加用例详细信息作为子节点（只保留测试步骤和预期结果）
            if case.get('测试步骤') or case.get('预期结果'):
                xml_content += '<children>\n<topics type="attached">\n'
                
                # 测试步骤
                if case.get('测试步骤'):
                    topic_index += 1
                    xml_content += f'''<topic id="{generate_topic_id(topic_index)}" modified-by="kiro" timestamp="{timestamp}">
<title>{case['测试步骤']}</title>
</topic>
'''
                
                # 预期结果
                if case.get('预期结果'):
                    topic_index += 1
                    xml_content += f'''<topic id="{generate_topic_id(topic_index)}" modified-by="kiro" timestamp="{timestamp}">
<title>{case['预期结果']}</title>
</topic>
'''
                
                xml_content += '</topics>\n</children>\n'
            
            xml_content += '</topic>\n'
        
        xml_content += '''</topics>
</children>
</topic>
'''
    
    xml_content += '''</topics>
</children>
</topic>
</sheet>
</xmap-content>'''
    
    return xml_content

def create_meta_xml():
    """创建meta.xml"""
    return '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<meta xmlns="urn:xmind:xmap:xmlns:meta:2.0" version="2.0">
<Author>
<Name>Kiro</Name>
</Author>
</meta>'''

def create_styles_xml():
    """创建styles.xml"""
    return '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xmap-styles xmlns="urn:xmind:xmap:xmlns:style:2.0" xmlns:fo="http://www.w3.org/1999/XSL/Format" xmlns:svg="http://www.w3.org/2000/svg" version="2.0">
<styles>
<style id="default" name="default" type="theme">
<topic-properties line-class="org.xmind.branchConnection.curve" line-width="1pt" shape-class="org.xmind.topicShape.roundedRect">
<border-line-color svg:color="#558ED5"/>
</topic-properties>
</style>
</styles>
<automatic-styles/>
</xmap-styles>'''

def create_manifest_xml():
    """创建manifest.xml"""
    return '''<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<manifest xmlns="urn:xmind:xmap:xmlns:manifest:1.0">
<file-entry full-path="content.xml" media-type="text/xml"/>
<file-entry full-path="META-INF/" media-type=""/>
<file-entry full-path="META-INF/manifest.xml" media-type="text/xml"/>
<file-entry full-path="meta.xml" media-type="text/xml"/>
<file-entry full-path="styles.xml" media-type="text/xml"/>
</manifest>'''

def create_xmind_file(csv_file, output_file):
    """创建XMind文件"""
    
    print(f"正在读取CSV文件: {csv_file}")
    content_xml = create_xmind_content(csv_file)
    
    print(f"正在创建XMind文件: {output_file}")
    
    # 创建zip文件（xmind格式）
    with zipfile.ZipFile(output_file, 'w', zipfile.ZIP_DEFLATED) as xmind_zip:
        # 添加content.xml
        xmind_zip.writestr('content.xml', content_xml)
        
        # 添加meta.xml
        xmind_zip.writestr('meta.xml', create_meta_xml())
        
        # 添加styles.xml
        xmind_zip.writestr('styles.xml', create_styles_xml())
        
        # 添加manifest.xml
        xmind_zip.writestr('META-INF/manifest.xml', create_manifest_xml())
    
    print(f"✅ XMind文件创建成功: {output_file}")
    print(f"文件大小: {os.path.getsize(output_file)} bytes")

if __name__ == '__main__':
    csv_file = 'Mytest/特征平台测试/特征平台_完整测试用例_最终版.csv'
    output_file = 'Mytest/特征平台测试/特征平台_完整测试用例_最终版.xmind'
    
    create_xmind_file(csv_file, output_file)
