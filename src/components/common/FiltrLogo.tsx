import React from 'react';

interface FiltrLogoProps {
  className?: string;
  size?: 'sm' | 'md' | 'lg';
  showText?: boolean;
}

export const FiltrLogo: React.FC<FiltrLogoProps> = ({
  className = '',
  size = 'md',
  showText = true,
}) => {
  const iconDimensions = {
    sm: { w: 26, h: 26 },
    md: { w: 34, h: 34 },
    lg: { w: 44, h: 44 },
  }[size];

  return (
    <div className={`flex items-center gap-2.5 select-none ${className}`}>
      {/* Fancy Geometric Prism-Shield Vector Mark */}
      <div className="relative flex items-center justify-center shrink-0 group">
        <div className="absolute -inset-1 rounded-xl bg-gradient-to-r from-indigo-500/20 via-violet-500/20 to-cyan-500/20 blur-sm opacity-70 group-hover:opacity-100 transition-opacity" />
        <svg
          width={iconDimensions.w}
          height={iconDimensions.h}
          viewBox="0 0 64 64"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          className="relative drop-shadow-sm transition-transform duration-300 group-hover:scale-105"
        >
          <defs>
            <linearGradient id="filtrPrimary" x1="8" y1="8" x2="56" y2="56" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#4F46E5" />
              <stop offset="50%" stopColor="#7C3AED" />
              <stop offset="100%" stopColor="#06B6D4" />
            </linearGradient>

            <linearGradient id="filtrFacet1" x1="12" y1="16" x2="32" y2="48" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#6366F1" />
              <stop offset="100%" stopColor="#4338CA" />
            </linearGradient>

            <linearGradient id="filtrFacet2" x1="32" y1="16" x2="52" y2="48" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#06B6D4" />
              <stop offset="100%" stopColor="#0891B2" />
            </linearGradient>

            <linearGradient id="filtrCore" x1="24" y1="20" x2="40" y2="44" gradientUnits="userSpaceOnUse">
              <stop offset="0%" stopColor="#FFFFFF" stopOpacity="0.9" />
              <stop offset="100%" stopColor="#C7D2FE" stopOpacity="0.7" />
            </linearGradient>

            <filter id="softGlow" x="-20%" y="-20%" width="140%" height="140%">
              <feGaussianBlur stdDeviation="2" result="blur" />
              <feComposite in="SourceGraphic" in2="blur" operator="over" />
            </filter>
          </defs>

          {/* Outer Protective Shield Geometry */}
          <path
            d="M32 4L54 14V30C54 44.5 44.5 56.5 32 60C19.5 56.5 10 44.5 10 30V14L32 4Z"
            fill="url(#filtrPrimary)"
            className="transition-all duration-300"
          />

          {/* Precision Optical Facets (Representing multi-stage privacy filtering) */}
          <path
            d="M32 9L49 17V30C49 41.5 41.5 51.5 32 54.8V9Z"
            fill="url(#filtrFacet2)"
            fillOpacity="0.85"
          />
          <path
            d="M32 9L15 17V30C15 41.5 22.5 51.5 32 54.8V9Z"
            fill="url(#filtrFacet1)"
            fillOpacity="0.9"
          />

          {/* Central Filter Wave Aperture */}
          <path
            d="M20 22C24 22 28 28 32 28C36 28 40 22 44 22"
            stroke="#FFFFFF"
            strokeWidth="3"
            strokeLinecap="round"
            strokeOpacity="0.85"
          />
          <path
            d="M24 32C27 32 30 36 32 36C34 36 37 32 40 32"
            stroke="#A5F3FC"
            strokeWidth="3"
            strokeLinecap="round"
            strokeOpacity="0.9"
          />
          <path
            d="M28 42C30 42 31 44 32 44C33 44 34 42 36 42"
            stroke="#FFFFFF"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeOpacity="0.95"
          />

          {/* Glowing Center Core Pivot */}
          <circle cx="32" cy="36" r="2" fill="#FFFFFF" />
        </svg>
      </div>

      {/* Fancy Typography & Enterprise Identity */}
      {showText && (
        <div className="flex flex-col">
          <div className="flex items-center gap-2">
            <span className="text-xl font-extrabold tracking-tight font-sans text-slate-900 leading-none">
              <span className="bg-gradient-to-r from-indigo-600 via-violet-600 to-cyan-600 bg-clip-text text-transparent">
                filtr
              </span>
            </span>
            <span className="text-[10px] font-mono font-semibold tracking-wider uppercase px-1.5 py-0.5 rounded-md bg-indigo-50 text-indigo-700 border border-indigo-200/70 shadow-xs">
              SECURE
            </span>
          </div>
          <span className="text-[10px] font-medium text-slate-400 tracking-wide mt-0.5 hidden sm:inline">
            Enterprise Privacy Gateway
          </span>
        </div>
      )}
    </div>
  );
};
