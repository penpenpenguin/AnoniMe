from huggingface_hub import hf_hub_download
print("downloading...")
p = hf_hub_download("meta-llama/Meta-Llama-3.1-8B-Instruct", "config.json")
print("ok:", p)