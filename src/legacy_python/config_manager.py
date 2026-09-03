"""
Copy of src/config_manager.py (archived)
"""

import json
import os
from pathlib import Path
from typing import Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)

class ConfigManager:
    """統一設定管理システム"""
    
    def __init__(self, config_dir: str = "./config"):
        self.config_dir = Path(config_dir)
        self.config_dir.mkdir(exist_ok=True)
        self.configs: Dict[str, Any] = {}
        self._load_all_configs()
    
    def _load_all_configs(self):
        """全設定ファイルをロード"""
        config_files = {
            'app': 'app.json',
            'llm': 'llm.json',
            'search': 'search.json',
            'memory': 'memory.json',
            'voice': 'voice.json',
            'avatar': 'avatar.json',
            'ai_profiles': 'ai_profiles.json'
        }
        
        for key, filename in config_files.items():
            config_path = self.config_dir / filename
            try:
                if config_path.exists():
                    with open(config_path, 'r', encoding='utf-8') as f:
                        self.configs[key] = json.load(f)
                    logger.info(f"Loaded config: {key}")
            except Exception as e:
                logger.error(f"Error loading {filename}: {e}")
                self.configs[key] = {}
    
    def get(self, config_name: str, key: Optional[str] = None, default: Any = None) -> Any:
        """設定値を取得"""
        if config_name not in self.configs:
            return default
        
        if key is None:
            return self.configs[config_name]
        
        keys = key.split('.')
        value = self.configs[config_name]
        for k in keys:
            if isinstance(value, dict):
                value = value.get(k, default)
            else:
                return default
        return value
    
    def reload(self, config_name: str):
        """設定を再ロード"""
        config_path = self.config_dir / f"{config_name}.json"
        if config_path.exists():
            with open(config_path, 'r', encoding='utf-8') as f:
                self.configs[config_name] = json.load(f)
            logger.info(f"Reloaded config: {config_name}")

config_manager = ConfigManager()
