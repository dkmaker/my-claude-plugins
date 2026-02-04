#!/usr/bin/env python3
"""
Gemini Image Generation CLI
Supports both standard (fast) and pro (high quality) models
"""

import argparse
import os
import sys
import time
from io import BytesIO
from pathlib import Path
from typing import List, Optional

try:
    from google import genai
    from google.genai import types
    from PIL import Image
except ImportError:
    print("Error: Required packages not installed.")
    print("Please run: pip install -r requirements.txt")
    sys.exit(1)


class GeminiImageCLI:
    # Model identifiers (per Google docs: https://ai.google.dev/gemini-api/docs/image-generation)
    # Pro model: supports 1K, 2K, 4K resolutions - higher quality, slower
    MODEL_PRO = "gemini-3-pro-image-preview"
    # Flash model: fixed ~1K resolution only (no imageSize param) - faster generation
    MODEL_FLASH = "gemini-2.5-flash-image"

    # Supported aspect ratios (both models)
    ASPECT_RATIOS = ["1:1", "3:4", "4:3", "2:3", "3:2", "4:5", "5:4", "16:9", "9:16", "21:9"]

    # Supported resolutions (Pro model only - Flash is fixed at ~1K)
    RESOLUTIONS = ["1K", "2K", "4K"]

    def __init__(self, api_key: Optional[str] = None):
        """Initialize the CLI with API credentials."""
        # Get API key from parameter or environment variable
        # Note: Claude Code injects env vars from settings.local.json automatically
        self.api_key = api_key or os.environ.get("GEMINI_API_KEY")

        if not self.api_key:
            print("Error: No API key found!")
            print("Please set GEMINI_API_KEY environment variable or provide via --api-key")
            sys.exit(1)

        # Initialize the client
        try:
            self.client = genai.Client(api_key=self.api_key)
        except Exception as e:
            print(f"Error initializing Gemini client: {e}")
            sys.exit(1)

    def generate_image(
        self,
        prompt: str,
        images: Optional[List[str]] = None,
        aspect_ratio: str = "1:1",
        resolution: str = "2K",
        output: str = "output.png",
        use_pro: bool = True,
        max_retries: int = 3
    ) -> bool:
        """
        Generate or edit an image using Gemini.

        Args:
            prompt: Text description of the image to generate
            images: List of input image paths for editing or reference
            aspect_ratio: Output aspect ratio (e.g., "16:9")
            resolution: Output resolution ("1K", "2K", or "4K")
            output: Output file path
            use_pro: Use Pro model (True) or standard (False)
            max_retries: Maximum number of retry attempts

        Returns:
            True if successful, False otherwise
        """
        model = self.MODEL_PRO if use_pro else self.MODEL_FLASH
        model_name = "Gemini Pro" if use_pro else "Gemini Flash"

        print(f"Using {model_name} ({model})")
        print(f"Prompt: {prompt}")
        if use_pro:
            print(f"Aspect Ratio: {aspect_ratio}, Resolution: {resolution}")
        else:
            print(f"Aspect Ratio: {aspect_ratio} (Flash model uses fixed ~1K resolution)")

        # Build contents array
        contents = [prompt]

        # Add reference images if provided
        if images:
            print(f"Loading {len(images)} reference image(s)...")
            for img_path in images:
                try:
                    img = Image.open(img_path)
                    contents.append(img)
                    print(f"  - Loaded: {img_path}")
                except Exception as e:
                    print(f"Error loading image {img_path}: {e}")
                    return False

        # Configure generation parameters
        # Note: Flash model doesn't support imageSize, only aspectRatio
        if use_pro:
            config = types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                image_config=types.ImageConfig(
                    aspect_ratio=aspect_ratio,
                    image_size=resolution
                )
            )
        else:
            # Flash model: no imageSize parameter
            config = types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                image_config=types.ImageConfig(
                    aspect_ratio=aspect_ratio
                )
            )

        # Attempt generation with retries
        for attempt in range(max_retries):
            try:
                print(f"\nGenerating image (attempt {attempt + 1}/{max_retries})...")
                start_time = time.time()

                response = self.client.models.generate_content(
                    model=model,
                    contents=contents,
                    config=config
                )

                elapsed = time.time() - start_time
                print(f"Generation completed in {elapsed:.1f}s")

                # Extract and save the generated image
                image_saved = False
                for part in response.candidates[0].content.parts:
                    if part.text is not None:
                        print(f"\nModel description: {part.text}")

                    elif part.inline_data is not None:
                        # Save the image
                        image = Image.open(BytesIO(part.inline_data.data))
                        image.save(output)
                        print(f"\n✓ Image saved to: {output}")
                        print(f"  Size: {image.size[0]}x{image.size[1]} pixels")
                        image_saved = True

                if not image_saved:
                    print("Warning: No image data found in response")
                    return False

                # Display token usage if available
                if hasattr(response, 'usage_metadata'):
                    usage = response.usage_metadata
                    print(f"\nToken usage:")
                    print(f"  Input: {usage.prompt_token_count}")
                    print(f"  Output: {usage.candidates_token_count}")
                    print(f"  Total: {usage.total_token_count}")

                return True

            except Exception as e:
                error_msg = str(e)
                print(f"Error: {error_msg}")

                # Check if it's a rate limit error
                if "429" in error_msg or "rate limit" in error_msg.lower():
                    if attempt < max_retries - 1:
                        wait_time = (2 ** attempt) + 1
                        print(f"Rate limited. Waiting {wait_time}s before retry...")
                        time.sleep(wait_time)
                        continue

                # For other errors, don't retry
                if attempt < max_retries - 1:
                    print(f"Retrying...")
                    time.sleep(1)
                else:
                    print(f"Failed after {max_retries} attempts")
                    return False

        return False


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description="Gemini Image Generation CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Generate a simple image
  python image_gen.py "A sunset over mountains"

  # High-quality 4K image with custom aspect ratio
  python image_gen.py "A futuristic city at night" --resolution 4K --aspect-ratio 16:9

  # Fast generation using standard model
  python image_gen.py "A cat wearing sunglasses" --fast

  # Edit an existing image
  python image_gen.py "Convert to black and white" --images photo.jpg --output bw.png

  # Multi-image fusion
  python image_gen.py "Combine these into a collage" --images img1.jpg img2.jpg img3.jpg
        """
    )

    parser.add_argument(
        "prompt",
        type=str,
        help="Text prompt describing the image to generate or edit"
    )

    parser.add_argument(
        "-i", "--images",
        nargs="+",
        metavar="PATH",
        help="Input image path(s) for editing or multi-image fusion"
    )

    parser.add_argument(
        "-o", "--output",
        default="output.png",
        metavar="PATH",
        help="Output image file path (default: output.png)"
    )

    parser.add_argument(
        "--aspect-ratio",
        choices=GeminiImageCLI.ASPECT_RATIOS,
        default="1:1",
        help="Output image aspect ratio (default: 1:1)"
    )

    parser.add_argument(
        "--resolution",
        choices=GeminiImageCLI.RESOLUTIONS,
        default="2K",
        help="Output image resolution (default: 2K)"
    )

    parser.add_argument(
        "--fast",
        action="store_true",
        help="Use Gemini Flash for faster generation (fixed ~1K resolution)"
    )

    parser.add_argument(
        "--api-key",
        metavar="KEY",
        help="Gemini API key (or set GEMINI_API_KEY environment variable)"
    )

    parser.add_argument(
        "--retries",
        type=int,
        default=3,
        metavar="N",
        help="Maximum number of retry attempts (default: 3)"
    )

    return parser


def main():
    """Main entry point for the CLI."""
    parser = create_parser()
    args = parser.parse_args()

    # Initialize the CLI
    cli = GeminiImageCLI(api_key=args.api_key)

    # Generate the image
    # Fast mode uses gemini-2.5-flash-image (faster, fixed ~1K resolution)
    # Pro mode uses gemini-3-pro-image-preview (slower, supports 1K/2K/4K)
    success = cli.generate_image(
        prompt=args.prompt,
        images=args.images,
        aspect_ratio=args.aspect_ratio,
        resolution=args.resolution,
        output=args.output,
        use_pro=not args.fast,
        max_retries=args.retries
    )

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
