<script setup>
import { onMounted, onUnmounted } from 'vue'
import { callRuby } from '../bridge.js'
import { t } from '../i18n/index.js'

// Модальная справка по расширению (кнопка «?» в шапке панели).
const props = defineProps({
  version: { type: String, default: '' }
})
const emit = defineEmits(['close'])

function onKey(e) {
  if (e.key === 'Escape') emit('close')
}
onMounted(() => window.addEventListener('keydown', onKey))
onUnmounted(() => window.removeEventListener('keydown', onKey))

function openReleases() {
  callRuby('open_releases')
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4"
    @click.self="emit('close')"
  >
    <div class="max-h-full w-full max-w-md overflow-y-auto rounded-xl bg-white shadow-xl dark:bg-slate-900">
      <header class="flex items-center justify-between border-b border-slate-200 px-4 py-3 dark:border-slate-800">
        <h2 class="text-sm font-semibold text-slate-800 dark:text-slate-100">{{ t('help.title') }}</h2>
        <button
          type="button"
          :title="t('help.close')"
          :aria-label="t('help.closeAria')"
          class="rounded-full p-1.5 text-slate-400 transition-colors hover:bg-slate-100 hover:text-slate-600 dark:text-slate-500 dark:hover:bg-slate-800 dark:hover:text-slate-300"
          @click="emit('close')"
        >
          <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M18 6 6 18" />
            <path d="m6 6 12 12" />
          </svg>
        </button>
      </header>

      <div class="space-y-4 px-4 py-3 text-xs leading-relaxed text-slate-600 dark:text-slate-300">
        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800 dark:text-slate-100">{{ t('help.whatTitle') }}</h3>
          <p>{{ t('help.whatText') }}</p>
        </section>

        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800 dark:text-slate-100">{{ t('help.workflowTitle') }}</h3>
          <ol class="list-decimal space-y-1 pl-4">
            <li>{{ t('help.step1') }}</li>
            <li>{{ t('help.step2') }}</li>
            <li>{{ t('help.step3') }}</li>
          </ol>
        </section>

        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800 dark:text-slate-100">{{ t('help.settingsTitle') }}</h3>
          <p>{{ t('help.settingsText') }}</p>
        </section>

        <section>
          <h3 class="mb-1 text-xs font-semibold text-slate-800 dark:text-slate-100">{{ t('help.updatesTitle') }}</h3>
          <p>{{ t('help.updatesText') }}</p>
        </section>
      </div>

      <footer class="flex items-center justify-between border-t border-slate-200 px-4 py-3 text-xs dark:border-slate-800">
        <span class="text-slate-400 dark:text-slate-500">DN1Sup{{ version ? ` · версия ${version}` : '' }}</span>
        <button
          type="button"
          class="font-medium text-sky-600 transition-colors hover:text-sky-700 dark:text-sky-400 dark:hover:text-sky-300"
          @click="openReleases"
        >
          {{ t('help.releasesPage') }}
        </button>
      </footer>
    </div>
  </div>
</template>
