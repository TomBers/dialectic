defmodule DialecticWeb.AmbassadorLive do
  use DialecticWeb, :live_view

  alias Dialectic.Ambassadors

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "The Ambassador Programme — RationalGrid",
       page_title_suffix: "",
       page_description:
         "Lead the next chapter of learning. Register your interest in a branded RationalGrid teaching hub, guided AI learning, and a share of subscription revenue.",
       form: to_form(Ambassadors.change_interest(), as: :interest),
       joined?: false,
       signup_available?: Ambassadors.configured?(),
       submission_error: nil
     ), layout: false}
  end

  @impl true
  def handle_event("select-student", _params, socket) do
    form =
      socket.assigns.form.params
      |> Map.put("role", "student")
      |> Ambassadors.change_interest()
      |> to_form(as: :interest)

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("validate", %{"interest" => params}, socket) do
    form =
      params
      |> Ambassadors.change_interest()
      |> Map.put(:action, :validate)
      |> to_form(as: :interest)

    {:noreply, assign(socket, form: form, submission_error: nil)}
  end

  def handle_event("join", _params, %{assigns: %{joined?: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("join", %{"interest" => params}, socket) do
    save_interest(socket, params)
  end

  defp save_interest(socket, params) do
    socket = assign(socket, :form, to_form(Ambassadors.change_interest(params), as: :interest))

    case Ambassadors.register_interest(params) do
      {:ok, _interest} ->
        {:noreply, assign(socket, joined?: true, submission_error: nil)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: :interest))}

      {:error, :not_configured} ->
        {:noreply,
         assign(socket, :submission_error, "Registration opens soon. Please check back shortly.")}

      {:error, _reason} ->
        {:noreply,
         assign(
           socket,
           :submission_error,
           "We couldn’t save your details. Please try again shortly."
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="ambassador-page" class="ambassador-page">
        <header class="amb-nav">
          <a id="ambassador-home-link" href={~p"/"} class="amb-brand" aria-label="RationalGrid home">
            <span class="amb-brand-icon">
              <img
                id="ambassador-logo"
                src={~p"/images/brandmark.svg"}
                alt=""
                width="24"
                height="24"
                class="h-6 w-6"
              />
            </span>
            RationalGrid<span class="amb-brand-dot">.</span>
          </a>
          <nav aria-label="Ambassador programme" class="amb-nav-links">
            <a id="amb-how-link" href="#how-it-works" class="amb-nav-secondary">How it works</a>
            <a id="amb-benefits-link" href="#why-join" class="amb-nav-secondary">Why join?</a>
            <a id="amb-faq-link" href="#ambassador-faq" class="amb-nav-secondary">FAQs</a>
            <a id="amb-nav-join" href="#join-programme" class="amb-button amb-button-small">
              Become an ambassador <.icon name="hero-arrow-up-right" class="h-4 w-4" />
            </a>
          </nav>
        </header>

        <section id="ambassador-hero" class="amb-hero amb-container" aria-labelledby="amb-hero-title">
          <div class="amb-hero-copy">
            <p class="amb-eyebrow"><span class="amb-status-dot"></span> THE AMBASSADOR PROGRAMME</p>
            <h1 id="amb-hero-title">The future of learning.<br />Led by <em>you.</em></h1>
            <p class="amb-hero-description">
              Built on RationalGrid: ask a question, explore connected ideas in a growing grid,
              and challenge answers as you go. The ambassador programme brings that approach
              to your community through your own branded learning hub, guided by your expertise.
            </p>
            <div class="amb-hero-actions">
              <a id="amb-hero-join" href="#join-programme" class="amb-button">
                Join the movement <.icon name="hero-arrow-up-right" class="h-4 w-4" />
              </a>
              <a id="amb-hero-product" href={~p"/"} class="amb-text-link">
                Explore RationalGrid <.icon name="hero-arrow-up-right" class="h-4 w-4" />
              </a>
            </div>
            <p class="amb-hero-note">
              <.icon name="hero-check-circle" class="h-4 w-4" />
              Free to register your interest. A new chapter to help shape.
            </p>
          </div>

          <div
            id="ambassador-hub-preview"
            role="img"
            class="amb-hero-visual"
            aria-label="Illustrative preview of an educator’s branded learning hub"
          >
            <div class="amb-visual-orbit amb-orbit-one"></div>
            <div class="amb-visual-orbit amb-orbit-two"></div>
            <span class="amb-visual-star" aria-hidden="true">✳</span>
            <div class="amb-hub">
              <div class="amb-hub-browser">
                <span class="amb-browser-dots" aria-hidden="true"><i></i><i></i><i></i></span>
                <span><.icon name="hero-lock-closed" class="h-3 w-3" /> your learning space</span>
                <.icon name="hero-ellipsis-horizontal" class="h-4 w-4" />
              </div>
              <div class="amb-hub-header">
                <span class="amb-hub-monogram">JL</span>
                <div>
                  <strong>Jamie’s Learning Studio</strong><span>Powered by RationalGrid</span>
                </div>
                <span class="amb-hub-avatar">J</span>
              </div>
              <div class="amb-hub-content">
                <p class="amb-hub-kicker">A SPACE FOR CURIOUS MINDS</p>
                <h2>Big questions.<br />Better understanding.</h2>
                <p>Explore ideas. Challenge answers. Think for yourself.</p>
                <div class="amb-hub-tabs">
                  <span>Your learning space</span><span>Resources</span><span>Community</span>
                </div>
                <div class="amb-lesson">
                  <span class="amb-lesson-icon"><.icon name="hero-light-bulb" class="h-5 w-5" /></span>
                  <div>
                    <span>LET’S THINK ABOUT IT</span><strong>Can AI help us think more critically?</strong>
                  </div>
                  <.icon name="hero-arrow-up-right" class="h-4 w-4" />
                </div>
                <div class="amb-reasoning-path" aria-hidden="true"><span></span><span></span></div>
                <div class="amb-hub-topics">
                  <div>
                    <.icon name="hero-magnifying-glass" class="h-4 w-4" /><strong>Question the source</strong><span>Look beyond the answer</span>
                  </div>
                  <div>
                    <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" /><strong>Explore another view</strong><span>Make room for new ideas</span>
                  </div>
                </div>
              </div>
              <div class="amb-hub-footer">
                <span class="amb-status-dot"></span> Guided by an educator. Powered by curiosity.
              </div>
            </div>
            <div class="amb-float amb-float-brand">
              <span><.icon name="hero-swatch" class="h-5 w-5" /></span><div>
                <strong>Your brand. Your space.</strong><small>A hub that feels like you.</small>
              </div>
            </div>
            <div class="amb-float amb-float-earn">
              <span><.icon name="hero-arrow-trending-up" class="h-5 w-5" /></span><div>
                <strong>Teach. Inspire. Earn.</strong><small>Grow together, share the rewards.</small>
              </div>
            </div>
            <p class="amb-preview-label">
              A little glimpse of what we’re building. Illustrative preview.
            </p>
          </div>
        </section>

        <section class="amb-audience" aria-label="Who the programme is for">
          <div class="amb-container amb-audience-inner">
            <span>FOR THE PEOPLE WHO<br /><strong>MAKE LEARNING HAPPEN.</strong></span>
            <p><.icon name="hero-academic-cap" class="h-6 w-6" /> Educators</p>
            <p><.icon name="hero-chat-bubble-left-right" class="h-6 w-6" /> Independent tutors</p>
            <p><.icon name="hero-building-library" class="h-6 w-6" /> Schools & institutions</p>
            <p><.icon name="hero-user-group" class="h-6 w-6" /> Learning communities</p>
          </div>
        </section>

        <section id="how-it-works" class="amb-section amb-container" aria-labelledby="amb-how-title">
          <div class="amb-section-heading">
            <div>
              <p class="amb-eyebrow">A SHARED MISSION. A SHARED OPPORTUNITY.</p><h2 id="amb-how-title">
                Your teaching. A bigger impact.
              </h2>
            </div>
            <p>
              Bring your people. We’re building the tools.<br />Here’s how the programme is designed to work.
            </p>
          </div>
          <div class="amb-steps">
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-peach"><.icon name="hero-window" class="h-6 w-6" /></span><span>01 / MAKE IT YOURS</span>
              </div><h3>Your own branded hub</h3><p>
                A home for your teaching, with your identity at the centre. Welcome students into a learning space that feels like yours.
              </p>
            </article>
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-green"><.icon
                  name="hero-sparkles"
                  class="h-6 w-6"
                /></span><span>02 / GUIDE THE CURIOSITY</span>
              </div><h3>Lead a better way to learn</h3><p>
                Help students question, explore, and understand with AI. Keep your guidance and the integrity of information at the heart of learning.
              </p>
            </article>
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-purple"><.icon
                  name="hero-arrow-trending-up"
                  class="h-6 w-6"
                /></span><span>03 / SHARE IN THE GROWTH</span>
              </div><h3>Make your impact rewarding</h3><p>
                Earn a share of eligible student subscription revenue. When the learning community you bring grows, you benefit too.
              </p>
            </article>
          </div>
          <p class="amb-terms-note">
            We’re gathering early interest. Hub features, revenue share, and programme terms will be confirmed before launch.
          </p>
        </section>

        <section id="why-join" class="amb-mission amb-container" aria-labelledby="amb-mission-title">
          <div class="amb-mission-art" aria-hidden="true">
            <span class="amb-art-word">human</span>
            <span class="amb-art-plus">+</span>
            <span class="amb-art-ai">AI<span>✳</span></span>
            <span class="amb-art-caption">BETTER, TOGETHER.</span>
          </div>
          <div class="amb-mission-copy">
            <p class="amb-eyebrow">MORE HUMAN. NOT LESS.</p>
            <h2 id="amb-mission-title">
              AI is changing education.<br /><em>Educators should lead it.</em>
            </h2>
            <p>
              The next chapter isn’t about handing over the thinking. It’s about giving students a place to practise it, with someone they trust to guide them.
            </p>
            <ul>
              <li>
                <.icon name="hero-check-circle" class="h-5 w-5" /><span><strong>Understanding over shortcuts.</strong>
                Encourage questions, not just answers.</span>
              </li>
              <li>
                <.icon name="hero-check-circle" class="h-5 w-5" /><span><strong>Integrity at the centre.</strong>
                Make checking sources and challenging claims part of the process.</span>
              </li>
              <li>
                <.icon name="hero-check-circle" class="h-5 w-5" /><span><strong>You set the direction.</strong>
                Bring your expertise to the way your students use AI.</span>
              </li>
            </ul>
            <a id="amb-mission-join" href="#join-programme" class="amb-text-link">Help shape what comes next
            <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
          </div>
        </section>

        <section
          id="student-referrals"
          class="amb-referral amb-container"
          aria-labelledby="amb-referral-title"
        >
          <span class="amb-referral-icon"><.icon name="hero-users" class="h-7 w-7" /></span>
          <div>
            <p class="amb-eyebrow">GOOD IDEAS TRAVEL.</p><h2 id="amb-referral-title">
              A student? Bring a friend. Share the upside.
            </h2><p>
              We’re exploring peer referrals too — a share of eligible subscription fees when friends join through you. Register as a student to hear more.
            </p>
          </div>
          <a
            id="amb-student-join"
            href="#join-programme"
            class="amb-text-link"
            phx-click="select-student"
          >I’m interested <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
        </section>

        <section id="join-programme" class="amb-join amb-container" aria-labelledby="amb-join-title">
          <div class="amb-join-copy">
            <p class="amb-eyebrow">BE PART OF THE NEXT CHAPTER</p><h2 id="amb-join-title">
              A learning revolution.<br /><em>With you at the heart.</em>
            </h2><p>
              Join the educators, tutors, and curious minds who want to help shape a more thoughtful future for AI in education.
            </p><span><.icon name="hero-arrow-up-right" class="h-5 w-5" /> Early interest is now open</span>
          </div>
          <div class="amb-signup-card">
            <div
              :if={@joined?}
              id="ambassador-success"
              class="amb-success"
              role="status"
              aria-live="polite"
            >
              <span class="amb-success-icon"><.icon name="hero-check" class="h-7 w-7" /></span>
              <h3>You’re on the list.</h3>
              <p>
                Thanks for helping shape what comes next. We’ve saved your interest and will be in touch with programme updates and early-access opportunities.
              </p>
              <a id="amb-success-explore" href={~p"/community"} class="amb-text-link">Explore RationalGrid
              <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
            </div>
            <.form
              :if={!@joined?}
              for={@form}
              id="ambassador-interest-form"
              phx-change="validate"
              phx-submit="join"
            >
              <h3>Let’s build this together.</h3>
              <p>Leave your email. Be first to hear what’s next.</p>
              <.input
                field={@form[:email]}
                type="email"
                label="Email address"
                placeholder="you@example.com"
                autocomplete="email"
                required
                maxlength="254"
                class="amb-input"
              />
              <.input
                field={@form[:role]}
                type="select"
                label="I’m joining as…"
                prompt="Choose your role"
                options={[
                  {"An educator", "educator"},
                  {"An independent tutor", "tutor"},
                  {"A school or institution", "institution"},
                  {"A student", "student"},
                  {"Other", "other"}
                ]}
                required
                class="amb-input"
              />
              <.input
                :if={@form[:role].value in ["other", :other]}
                field={@form[:other_role]}
                label="Your role"
                placeholder="Tell us how you’re involved in learning"
                maxlength="100"
                required
                class="amb-input"
              />
              <p
                :if={@submission_error}
                id="ambassador-submit-error"
                role="alert"
                class="amb-form-error"
              >
                {@submission_error}
              </p>
              <button
                id="ambassador-submit"
                type="submit"
                class="amb-button"
                disabled={!@signup_available?}
                phx-disable-with="Saving your interest…"
              >Register my interest <.icon name="hero-arrow-up-right" class="h-4 w-4" /></button>
              <p
                :if={!@signup_available?}
                id="ambassador-registration-pending"
                role="status"
                class="amb-signup-note"
              >
                Registration opens soon. Please check back shortly.
              </p>
              <p class="amb-signup-note">
                By joining, you’re asking to receive emails about this programme. No account, payment, or commitment required.
              </p>
            </.form>
          </div>
        </section>

        <section id="ambassador-faq" class="amb-faq amb-container" aria-labelledby="amb-faq-title">
          <div>
            <p class="amb-eyebrow">A FEW THINGS YOU MIGHT BE WONDERING</p><h2 id="amb-faq-title">
              Good questions.<br />Thoughtful answers.
            </h2>
          </div>
          <div class="amb-faq-items">
            <details id="amb-faq-try-today">
              <summary>
                How can I try RationalGrid today?<.icon name="hero-plus" class="h-4 w-4" />
              </summary>
              <p>
                RationalGrid is available now. Start with a question, explore the connected ideas
                in your grid, and challenge or unpack any answer. You can try Simple answers
                without an account, or sign up free to save bookmarks and highlights.
                You don’t need to wait for the ambassador programme to launch.
                <a
                  id="amb-faq-try-link"
                  href={~p"/?focus=grid#start-here"}
                  class="amb-text-link underline underline-offset-4"
                >Try RationalGrid now <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
              </p>
            </details>
            <details id="amb-faq-eligibility">
              <summary>
                Who can become an ambassador?<.icon name="hero-plus" class="h-4 w-4" />
              </summary><p>
                We’d love to hear from teachers, lecturers, independent tutors, schools, and institutions interested in guiding thoughtful AI use. Students can also register interest in the proposed peer referral programme.
              </p>
            </details>
            <details id="amb-faq-cost">
              <summary>
                Does it cost anything to join?<.icon name="hero-plus" class="h-4 w-4" />
              </summary><p>
                Registering your interest is free and involves no commitment. We’ll share pricing and full programme terms before you decide whether to take part.
              </p>
            </details>
            <details id="amb-faq-earnings">
              <summary>
                How will revenue sharing work?<.icon name="hero-plus" class="h-4 w-4" />
              </summary><p>
                The proposed model gives educators a share of eligible subscriptions from students they bring to their hub, with a separate referral opportunity for students. Rates, eligibility, and payment terms are still being developed and will be confirmed before launch.
              </p>
            </details>
            <details id="amb-faq-launch">
              <summary>When can I launch my hub?<.icon name="hero-plus" class="h-4 w-4" /></summary><p>
                We’re collecting interest to shape the first version of the programme. A launch date hasn’t been set yet. Join the list for updates and opportunities to help shape early access.
              </p>
            </details>
            <details id="amb-faq-integrity">
              <summary>
                How does this support academic integrity?<.icon name="hero-plus" class="h-4 w-4" />
              </summary><p>
                The aim is educator-guided exploration: questioning answers, checking sources, and developing understanding. AI can make mistakes, so your judgement and your institution’s policies remain essential. The hub preview shows our direction; specific controls will be shaped with early participants.
              </p>
            </details>
          </div>
        </section>

        <footer class="amb-footer amb-container">
          <a href={~p"/"} class="amb-brand">
            <span class="amb-brand-icon">
              <img
                id="amb-footer-logo"
                src={~p"/images/brandmark.svg"}
                alt=""
                width="20"
                height="20"
                class="h-5 w-5"
              />
            </span>
            RationalGrid<span class="amb-brand-dot">.</span>
          </a><p>
            Independent thinking. Shared possibility.
          </p><a id="amb-footer-about" href={~p"/about"}>Get to know RationalGrid
          <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
        </footer>
      </div>
    </Layouts.app>
    """
  end
end
