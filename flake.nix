{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    python3Overlay = final: prev: pfinal: pprev:
      pprev.buildPythonPackage {
        pname = "fastchat";
        version = "2023.04.15";
        format = "pyproject";

        src = self;

        nativeBuildInputs = [
          pprev.setuptools
        ];

        propagatedBuildInputs = with pfinal; [
          (pprev.buildPythonPackage rec {
            pname = "accelerate";
            version = "0.18.0";

            src = pprev.fetchPypi {
              inherit pname version;
              hash = "sha256-HdNv2XLeSm0M/+Xk1tMGIv2FN2X3c7VYLPB5be7+EBY=";
            };

            nativeBuildInputs = with pprev; [
              setuptools
            ];

            propagatedBuildInputs = with pfinal; [
              numpy
              packaging
              psutil
              pyyaml
              torch
            ];
          })
          fastapi
          # gradio==3.23
          (pprev.buildPythonPackage rec {
            pname = "gradio";
            version = "3.23.0";
            format = "pyproject";

            src = pprev.fetchPypi {
              inherit pname version;
              hash = "sha256-v7n1nXmScQKeYwkgfH9C7YrbKX3Li74xyDw+vzLb4ZM=";
            };

            nativeBuildInputs = with pprev; [
              hatchling
              hatch-requirements-txt
              hatch-fancy-pypi-readme
            ];

            propagatedBuildInputs = with pfinal; [
              aiofiles
              aiohttp
              altair # >=4.2.0
              fastapi
              # ffmpy
              (pprev.buildPythonPackage rec {
                pname = "ffmpy";
                version = "0.3.0";

                # https://github.com/Ch00k/ffmpy/issues/60
                src = pprev.fetchPypi {
                  inherit pname version;
                  sha256 = "dXWRWB7uJbSlCsn/ubWANaJ5RTPbR+BRL1P7LXtvmtw=";
                };

                propagatedBuildInputs = [
                  prev.ffmpeg
                ];

                pythonImportsCheck = ["ffmpy"];

                meta = with nixpkgs.lib; {
                  description = "A simple python interface for FFmpeg/FFprobe";
                  homepage = "https://github.com/Ch00k/ffmpy";
                  license = licenses.mit;
                  maintainers = with maintainers; [pbsds];
                };
              })
              fsspec
              # gradio_client # >=0.1.3
              httpx
              huggingface-hub
              jinja2
              markdown-it-py # [linkify]>=2.0.0
              markdown-it-py.optional-dependencies.linkify
              (mdit-py-plugins.overrideAttrs (oA: {
                version = "0.3.3";
                src = prev.fetchFromGitHub {
                  owner = "executablebooks";
                  repo = "mdit-py-plugins";
                  rev = "refs/tags/v0.3.3";
                  hash = "sha256-9eaVM5KxrMY5q0c2KWmctCHyPGmEGGNa9B3LoRL/mcI=";
                };
              }))
              markupsafe
              matplotlib
              numpy
              orjson
              pandas
              pillow
              pydantic
              python-multipart
              pydub
              pyyaml
              requests
              semantic-version
              typing-extensions
              uvicorn
              wavedrom
              websockets #>=10.0
            ];
          })
          transformers
          markdown2
          numpy
          requests
          sentencepiece
          tokenizers
          torch
          uvicorn
          wandb
          prompt_toolkit
          rich
        ];
      };

    overlay = final: prev: {
      python3 = prev.python3.override {
        packageOverrides = pfinal: pprev: {
          huggingface-hub = pprev.huggingface-hub.overrideAttrs (oA: {
            version = "0.13.4";
            src = prev.fetchFromGitHub {
              owner = "huggingface";
              repo = "huggingface_hub";
              rev = "refs/tags/v0.13.4";
              hash = "sha256-gauEwI923jUd3kTZpQ2VRlpHNudytz5k10n1yFo0Mm8=";
            };
          });
          tokenizers = pprev.tokenizers.overrideAttrs (oA: rec {
            version = "0.13.3";
            src = prev.fetchFromGitHub {
              owner = "newAM";
              repo = oA.pname;
              rev = "2f9cedf12093fe8f4dd7231b11822c6e5e77fe16";
              hash = "sha256-QeyigJ7hF4bZKc007XrgPP8SPFO4at7xGVV3EnYVeBM=";
            };

            cargoDeps = prev.rustPlatform.fetchCargoTarball {
              inherit src;
              inherit (oA) sourceRoot;
              name = "${oA.pname}-${version}";
              hash = "sha256-um5ABsvrb2T7HYyTyI256NRCTNiTbJFASaUPYGo9INA=";
            };
          });
          torch = pprev.torch.override {
            cudaSupport = true;
          };
          transformers = pprev.transformers.overrideAttrs (oA: {
            version = "4.28.1";
            src = prev.fetchFromGitHub {
              owner = "huggingface";
              repo = "transformers";
              rev = "refs/tags/v4.28.1";
              hash = "sha256-FmiuWfoFZjZf1/GbE6PmSkeshWWh+6nDj2u2PMSeDk0=";
            };
          });

          fastchat = python3Overlay final prev pfinal pprev;
        };
      };

      python3Packages = final.python3.pkgs;
    };

    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [overlay];
      config.allowUnfreePredicate = pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [
          "cuda_cudart"
          "cuda_cupti"
          "cuda_nvcc"
          "cuda_nvprof"
          "cudatoolkit-11-cudnn"
          "cudatoolkit"
          "libcublas"
          "libcusparse"
        ];
    };
  in {
    packages.x86_64-linux.default = pkgs.python3Packages.fastchat;

    # nix develop -c python3 -m fastchat.serve.cli --model-path vicuna-7b
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = [
        pkgs.python3Packages.fastchat
      ];
    };
  };
}
