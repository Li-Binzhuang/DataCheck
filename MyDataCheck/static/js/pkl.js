// ========== PKL文件解析相关函数 ==========

let currentPklFile = null;
let currentPklData = null;

// PKL文件选择处理
document.addEventListener('DOMContentLoaded', function() {
    const pklFileInput = document.getElementById('pkl-file-input');
    if (pklFileInput) {
        pklFileInput.addEventListener('change', function(e) {
            const file = e.target.files[0];
            if (file) {
                if (!file.name.endsWith('.pkl')) {
                    showAlert('只支持PKL文件', 'error', 'api');
                    e.target.value = '';
                    return;
                }
                
                currentPklFile = file;
                const fileInfo = document.getElementById('pkl-file-info');
                fileInfo.textContent = `已选择: ${file.name} (${(file.size / 1024 / 1024).toFixed(2)} MB)`;
                fileInfo.style.color = '#28a745';
                
                // 启用按钮
                document.getElementById('btn-parse-pkl').disabled = false;
                document.getElementById('btn-convert-pkl').disabled = false;
                document.getElementById('btn-convert-cdcv2-pkl').disabled = false;
                
                // 隐藏之前的预览和结果
                document.getElementById('pkl-preview-container').style.display = 'none';
                document.getElementById('pkl-convert-result').style.display = 'none';
                currentPklData = null;
            }
        });
    }
});

// 解析PKL文件
async function parsePklFile() {
    if (!currentPklFile) {
        showAlert('请先选择PKL文件', 'error', 'api');
        return;
    }

    const fileInfo = document.getElementById('pkl-file-info');
    const previewContainer = document.getElementById('pkl-preview-container');
    const previewInfo = document.getElementById('pkl-preview-info');
    const previewData = document.getElementById('pkl-preview-data');
    const btnParse = document.getElementById('btn-parse-pkl');

    // 先上传文件
    fileInfo.textContent = `上传中: ${currentPklFile.name}...`;
    fileInfo.style.color = '#667eea';
    btnParse.disabled = true;

    try {
        // 上传文件（增加超时时间，大文件可能需要更长时间）
        const formData = new FormData();
        formData.append('file', currentPklFile);

        // 显示文件大小
        const fileSizeMB = (currentPklFile.size / 1024 / 1024).toFixed(2);
        if (parseFloat(fileSizeMB) > 50) {
            fileInfo.textContent = `上传中: ${currentPklFile.name} (${fileSizeMB} MB，大文件可能需要较长时间)...`;
        }

        const uploadController = new AbortController();
        const uploadTimeout = setTimeout(() => {
            uploadController.abort();
            throw new Error('上传超时，文件可能过大。请检查文件大小或网络连接。');
        }, 600000); // 10分钟超时（大文件）
        
        const uploadResponse = await fetch('/api/upload', {
            method: 'POST',
            body: formData,
            signal: uploadController.signal
        }).finally(() => clearTimeout(uploadTimeout));

        // 检查响应状态
        if (!uploadResponse.ok) {
            if (uploadResponse.status === 413) {
                const errorData = await uploadResponse.json().catch(() => ({}));
                throw new Error(errorData.error || '文件过大（413错误）');
            }
            throw new Error(`上传失败: HTTP ${uploadResponse.status}`);
        }
        
        const uploadData = await uploadResponse.json();

        if (!uploadData.success) {
            throw new Error(uploadData.error || '文件上传失败');
        }

        // 解析API需要PKL文件，所以使用原始PKL文件名（不是转换后的CSV文件名）
        const pklFilename = uploadData.converted ? uploadData.original_filename : (uploadData.filename || currentPklFile.name);

        // 解析文件
        fileInfo.textContent = `解析中: ${pklFilename}...`;
        
        const parseResponse = await fetch('/api/pkl/parse', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                filename: pklFilename,  // 使用PKL文件名，不是CSV文件名
                preview_rows: 10
            })
        });

        const parseResult = await parseResponse.json();

        if (parseResult.success) {
            currentPklData = parseResult.data;
            
            // 显示文件信息
            const info = parseResult.data;
            let infoHtml = `<div style="margin-bottom: 10px;"><strong>文件:</strong> ${info.file_name}</div>`;
            infoHtml += `<div style="margin-bottom: 10px;"><strong>数据类型:</strong> ${info.data_type}</div>`;
            
            if (info.type === 'DataFrame') {
                infoHtml += `<div style="margin-bottom: 10px;"><strong>形状:</strong> ${info.rows} 行 × ${info.cols} 列</div>`;
                infoHtml += `<div style="margin-bottom: 10px;"><strong>列数:</strong> ${info.cols}</div>`;
            } else if (info.type === 'dict') {
                infoHtml += `<div style="margin-bottom: 10px;"><strong>键数量:</strong> ${info.length}</div>`;
                if (info.keys && info.keys.length > 0) {
                    infoHtml += `<div style="margin-bottom: 10px;"><strong>键列表:</strong> ${info.keys.slice(0, 10).join(', ')}${info.keys.length > 10 ? '...' : ''}</div>`;
                }
            } else if (info.type === 'list') {
                infoHtml += `<div style="margin-bottom: 10px;"><strong>列表长度:</strong> ${info.length}</div>`;
            }
            
            previewInfo.innerHTML = infoHtml;

            // 显示预览数据（使用JSON格式显示）
            if (info.preview) {
                if (Array.isArray(info.preview)) {
                    // DataFrame预览 - JSON格式显示
                    previewData.innerHTML = `<pre style="margin: 0; white-space: pre-wrap; font-family: 'Courier New', monospace; background: #f5f5f5; padding: 15px; border-radius: 4px; overflow-x: auto; max-height: 500px; overflow-y: auto;">${JSON.stringify(info.preview, null, 2)}</pre>`;
                } else if (typeof info.preview === 'object') {
                    // 字典预览 - JSON格式显示
                    previewData.innerHTML = `<pre style="margin: 0; white-space: pre-wrap; font-family: 'Courier New', monospace; background: #f5f5f5; padding: 15px; border-radius: 4px; overflow-x: auto; max-height: 500px; overflow-y: auto;">${JSON.stringify(info.preview, null, 2)}</pre>`;
                } else {
                    previewData.innerHTML = `<pre style="margin: 0; white-space: pre-wrap; font-family: 'Courier New', monospace; background: #f5f5f5; padding: 15px; border-radius: 4px;">${String(info.preview)}</pre>`;
                }
            } else {
                previewData.innerHTML = '<div style="color: #666;">无预览数据</div>';
            }

            previewContainer.style.display = 'block';
            fileInfo.textContent = `✓ 解析完成: ${pklFilename}`;
            fileInfo.style.color = '#28a745';
            showAlert('PKL文件解析成功', 'success', 'api');
        } else {
            // 显示详细的错误信息
            let errorMsg = parseResult.error || '解析失败';
            if (parseResult.error_detail) {
                errorMsg += '\n\n' + parseResult.error_detail;
            }
            if (parseResult.install_command) {
                errorMsg += '\n\n安装命令: ' + parseResult.install_command;
            }
            throw new Error(errorMsg);
        }
    } catch (error) {
        fileInfo.textContent = `✗ ${error.name === 'AbortError' ? '上传超时' : '解析失败'}: ${error.message.split('\n')[0]}`;
        fileInfo.style.color = '#dc3545';
        
        // 显示详细的错误信息（包含安装说明）
        let errorDisplay = error.message;
        if (error.message.includes('413') || error.message.includes('文件过大') || error.message.includes('Request Entity Too Large')) {
            errorDisplay = '❌ 文件过大（413错误）\n\n上传的文件超过了服务器限制（最大1GB）。\n\n解决方案：\n1. 压缩文件后再上传\n2. 将大文件分割成多个小文件\n3. 使用命令行工具直接处理PKL文件：\n   cd MyDataCheck\n   source .venv/bin/activate\n   python -c "from common.pkl_converter import convert_pkl_to_csv; convert_pkl_to_csv(\'inputdata/api_comparison/your_file.pkl\')"';
        } else if (error.name === 'AbortError' || error.message.includes('超时')) {
            errorDisplay = '❌ 上传超时\n\n文件可能过大或网络连接不稳定。\n建议：\n1. 检查文件大小（建议小于1GB）\n2. 检查网络连接\n3. 如果文件确实很大，请耐心等待';
        } else if (error.message.includes('pandas')) {
            errorDisplay = '❌ pandas库未安装\n\n请执行以下步骤：\n1. 打开终端\n2. 进入项目目录: cd MyDataCheck\n3. 激活虚拟环境: source .venv/bin/activate\n4. 安装依赖: pip install pandas numpy\n\n或者直接安装所有依赖: pip install -r requirements.txt';
        } else if (error.message.includes('文件不存在')) {
            errorDisplay = '❌ 文件不存在\n\n可能的原因：\n1. 文件上传失败\n2. 文件名不正确\n3. 文件已被删除\n\n请重新上传文件';
        }
        
        showAlert(errorDisplay, 'error', 'api');
        console.error('解析PKL文件失败:', error);
    } finally {
        btnParse.disabled = false;
    }
}

// 转换PKL为CSV
async function convertPklToCsv() {
    if (!currentPklFile) {
        showAlert('请先选择PKL文件', 'error', 'api');
        return;
    }

    const fileInfo = document.getElementById('pkl-file-info');
    const convertResult = document.getElementById('pkl-convert-result');
    const convertInfo = document.getElementById('pkl-convert-info');
    const btnConvert = document.getElementById('btn-convert-pkl');

    fileInfo.textContent = `转换中: ${currentPklFile.name}...`;
    fileInfo.style.color = '#667eea';
    btnConvert.disabled = true;

    try {
        // 先上传文件（如果还没有上传）
        let filename = currentPklFile.name;
        
        // 检查文件是否已上传
        const formData = new FormData();
        formData.append('file', currentPklFile);

        const uploadResponse = await fetch('/api/upload', {
            method: 'POST',
            body: formData
        });

        const uploadData = await uploadResponse.json();

        if (!uploadData.success) {
            throw new Error(uploadData.error || '文件上传失败');
        }

        // 转换API需要PKL文件，所以使用原始PKL文件名（不是转换后的CSV文件名）
        const pklFilename = uploadData.converted ? uploadData.original_filename : (uploadData.filename || currentPklFile.name);

        // 转换为CSV
        const convertResponse = await fetch('/api/pkl/convert', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                filename: pklFilename  // 使用PKL文件名
            })
        });

        const convertData = await convertResponse.json();

        if (convertData.success) {
            let infoHtml = `<div style="margin-bottom: 10px;"><strong>✅ 转换成功!</strong></div>`;
            infoHtml += `<div style="margin-bottom: 10px;"><strong>输入文件:</strong> ${convertData.info.input_file}</div>`;
            infoHtml += `<div style="margin-bottom: 10px;"><strong>输出文件:</strong> ${convertData.info.output_file}</div>`;
            infoHtml += `<div style="margin-bottom: 10px;"><strong>数据行数:</strong> ${convertData.info.rows}</div>`;
            infoHtml += `<div style="margin-bottom: 10px;"><strong>数据列数:</strong> ${convertData.info.columns}</div>`;
            
            if (convertData.info.column_names && convertData.info.column_names.length > 0) {
                const colsPreview = convertData.info.column_names.slice(0, 10).join(', ');
                infoHtml += `<div style="margin-bottom: 10px;"><strong>列名（前10个）:</strong> ${colsPreview}${convertData.info.column_names.length > 10 ? '...' : ''}</div>`;
            }
            
            convertInfo.innerHTML = infoHtml;
            convertResult.style.display = 'block';
            fileInfo.textContent = `✓ 转换完成: ${convertData.csv_filename}`;
            fileInfo.style.color = '#28a745';
            showAlert(`CSV文件已生成: ${convertData.csv_filename}`, 'success', 'api');
        } else {
            // 显示详细的错误信息
            let errorMsg = convertData.error || '转换失败';
            if (convertData.info && convertData.info.error_detail) {
                errorMsg += '\n\n' + convertData.info.error_detail;
            }
            if (convertData.info && convertData.info.install_command) {
                errorMsg += '\n\n安装命令: ' + convertData.info.install_command;
            }
            throw new Error(errorMsg);
        }
    } catch (error) {
        fileInfo.textContent = `✗ 转换失败: ${error.message.split('\n')[0]}`;
        fileInfo.style.color = '#dc3545';
        
        // 显示详细的错误信息（包含安装说明）
        let errorDisplay = error.message;
        if (error.message.includes('pandas')) {
            errorDisplay = '❌ pandas库未安装\n\n请执行以下步骤：\n1. 打开终端\n2. 进入项目目录: cd MyDataCheck\n3. 激活虚拟环境: source .venv/bin/activate\n4. 安装依赖: pip install pandas numpy\n\n或者直接安装所有依赖: pip install -r requirements.txt';
        }
        
        showAlert(errorDisplay, 'error', 'api');
        console.error('转换PKL文件失败:', error);
    } finally {
        btnConvert.disabled = false;
    }
}

// 转换为cdcV2核心CSV
async function convertPklToCdcV2Csv() {
    if (!currentPklFile) {
        showAlert('请先选择PKL文件', 'error', 'api');
        return;
    }

    const fileInfo = document.getElementById('pkl-file-info');
    const convertResult = document.getElementById('pkl-convert-result');
    const convertInfo = document.getElementById('pkl-convert-info');
    const btnConvert = document.getElementById('btn-convert-cdcv2-pkl');

    fileInfo.textContent = `转换中（cdcV2核心CSV）: ${currentPklFile.name}...`;
    fileInfo.style.color = '#667eea';
    btnConvert.disabled = true;

    try {
        // 上传PKL文件（转换API需要PKL文件存在）
        const formData = new FormData();
        formData.append('file', currentPklFile);

        const uploadController3 = new AbortController();
        const uploadTimeout3 = setTimeout(() => uploadController3.abort(), 600000); // 10分钟超时
        
        const uploadResponse = await fetch('/api/upload', {
            method: 'POST',
            body: formData,
            signal: uploadController3.signal
        }).finally(() => clearTimeout(uploadTimeout3));

        // 检查响应状态
        if (!uploadResponse.ok) {
            if (uploadResponse.status === 413) {
                const errorData = await uploadResponse.json().catch(() => ({}));
                throw new Error(errorData.error || '文件过大（413错误）');
            }
            throw new Error(`上传失败: HTTP ${uploadResponse.status}`);
        }

        const uploadData = await uploadResponse.json();

        if (!uploadData.success) {
            throw new Error(uploadData.error || '文件上传失败');
        }

        // 转换API需要PKL文件，所以使用原始PKL文件名
        const pklFilename = uploadData.converted ? uploadData.original_filename : (uploadData.filename || currentPklFile.name);

        // 转换为cdcV2核心CSV
        const convertResponse = await fetch('/api/pkl/convert-cdcv2', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                filename: pklFilename
            })
        });

        const convertData = await convertResponse.json();

        if (convertData.success) {
            let infoHtml = `<div style="margin-bottom: 10px;"><strong>✅ cdcV2核心CSV生成成功!</strong></div>`;
            infoHtml += `<div style="margin-bottom: 10px;"><strong>输入文件:</strong> ${convertData.info.input_file}</div>`;
            infoHtml += `<div style="margin-bottom: 10px;"><strong>输出文件:</strong> ${convertData.info.output_file}</div>`;
            infoHtml += `<div style="margin-bottom: 10px;"><strong>数据行数:</strong> ${convertData.info.rows}</div>`;
            infoHtml += `<div style="margin-bottom: 10px;"><strong>总列数:</strong> ${convertData.info.columns} (基础列: ${convertData.info.base_columns}, 特征列: ${convertData.info.feature_columns})</div>`;
            
            if (convertData.info.column_names && convertData.info.column_names.length > 0) {
                const baseCols = convertData.info.column_names.slice(0, 2);
                const featureColsPreview = convertData.info.column_names.slice(2, 12).join(', ');
                infoHtml += `<div style="margin-bottom: 10px;"><strong>基础列:</strong> ${baseCols.join(', ')}</div>`;
                infoHtml += `<div style="margin-bottom: 10px;"><strong>特征列（前10个）:</strong> ${featureColsPreview}${convertData.info.feature_columns > 10 ? '...' : ''}</div>`;
            }
            
            convertInfo.innerHTML = infoHtml;
            convertResult.style.display = 'block';
            fileInfo.textContent = `✓ cdcV2核心CSV生成完成: ${convertData.csv_filename}`;
            fileInfo.style.color = '#28a745';
            showAlert(`cdcV2核心CSV已生成: ${convertData.csv_filename}`, 'success', 'api');
        } else {
            // 显示详细的错误信息
            let errorMsg = convertData.error || '转换失败';
            if (convertData.info && convertData.info.error_detail) {
                errorMsg += '\n\n' + convertData.info.error_detail;
            }
            if (convertData.info && convertData.info.install_command) {
                errorMsg += '\n\n安装命令: ' + convertData.info.install_command;
            }
            throw new Error(errorMsg);
        }
    } catch (error) {
        fileInfo.textContent = `✗ 转换失败: ${error.message.split('\n')[0]}`;
        fileInfo.style.color = '#dc3545';
        
        // 显示详细的错误信息
        let errorDisplay = error.message;
        if (error.name === 'AbortError' || error.message.includes('超时')) {
            errorDisplay = '❌ 上传超时\n\n文件可能过大或网络连接不稳定。\n建议：\n1. 检查文件大小（建议小于1GB）\n2. 检查网络连接\n3. 如果文件确实很大，请耐心等待';
        } else if (error.message.includes('pandas')) {
            errorDisplay = '❌ pandas库未安装\n\n请执行以下步骤：\n1. 打开终端\n2. 进入项目目录: cd MyDataCheck\n3. 激活虚拟环境: source .venv/bin/activate\n4. 安装依赖: pip install pandas numpy\n\n或者直接安装所有依赖: pip install -r requirements.txt';
        } else if (error.message.includes('缺少') || error.message.includes('apply_id') || error.message.includes('response_body')) {
            errorDisplay = `❌ 数据格式错误\n\n${error.message}\n\n请确保PKL文件包含以下列：\n- apply_id\n- apply_time\n- response_body`;
        }
        
        showAlert(errorDisplay, 'error', 'api');
        console.error('转换cdcV2核心CSV失败:', error);
    } finally {
        btnConvert.disabled = false;
    }
}

function showAlert(message, type, tab = 'api') {
    const container = document.getElementById(`alert-container-${tab}`);
    const alert = document.createElement('div');
    alert.className = `alert alert-${type} show`;
    alert.textContent = message;
    container.innerHTML = '';
    container.appendChild(alert);
    
    setTimeout(() => {
        alert.classList.remove('show');
        setTimeout(() => alert.remove(), 300);
    }, 3000);
}

