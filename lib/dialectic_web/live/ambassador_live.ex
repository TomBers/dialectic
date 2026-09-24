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
         "Bring your teaching beyond the lesson with RationalGrid. Help students revisit ideas, deepen understanding, and explore a proposed share of subscription revenue.",
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
            <a id="amb-earn-link" href="#how-you-earn" class="amb-nav-secondary">How you earn</a>
            <a id="amb-benefits-link" href="#why-join" class="amb-nav-secondary">Why join?</a>
            <a id="amb-faq-link" href="#ambassador-faq" class="amb-nav-secondary">FAQs</a>
            <a id="amb-nav-join" href="#join-programme" class="amb-button amb-button-small">
              Register your interest <.icon name="hero-arrow-up-right" class="h-4 w-4" />
            </a>
          </nav>
        </header>

        <section id="ambassador-hero" class="amb-hero amb-container" aria-labelledby="amb-hero-title">
          <div class="amb-hero-copy">
            <p class="amb-eyebrow"><span class="amb-status-dot"></span> THE AMBASSADOR PROGRAMME</p>
            <h1 id="amb-hero-title">We’re RationalGrid.<br />Teach. Guide. <em>Earn.</em></h1>
            <p class="amb-hero-description">
              Bring AI into learning and exploration through a shared whiteboard of connected
              ideas. See the questions students ask, follow how their exploration develops, and
              help them build on it. Our proposed ambassador programme would give you a branded
              RationalGrid hub to extend your teaching and earn a share of eligible student
              subscriptions.
            </p>
            <div class="amb-hero-actions">
              <a id="amb-hero-join" href="#join-programme" class="amb-button">
                Register your interest <.icon name="hero-arrow-up-right" class="h-4 w-4" />
              </a>
              <a id="amb-hero-product" href={~p"/"} class="amb-button amb-button-product">
                Explore RationalGrid <.icon name="hero-arrow-up-right" class="h-4 w-4" />
              </a>
            </div>
            <p class="amb-hero-note">
              <.icon name="hero-check-circle" class="h-4 w-4" />
              Try RationalGrid today. Help shape the ambassador programme before launch.
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
                <p class="amb-hub-kicker">KEEP LEARNING BETWEEN LESSONS</p>
                <h2>Revisit an idea.<br />Take it further.</h2>
                <p>Pick up a question. Check your understanding. Bring back what’s unclear.</p>
                <div class="amb-hub-tabs">
                  <span>Your learning space</span><span>Resources</span><span>Community</span>
                </div>
                <div class="amb-lesson">
                  <span class="amb-lesson-icon"><.icon name="hero-light-bulb" class="h-5 w-5" /></span>
                  <div>
                    <span>BEFORE OUR NEXT LESSON</span><strong>What makes a source trustworthy?</strong>
                  </div>
                  <.icon name="hero-arrow-up-right" class="h-4 w-4" />
                </div>
                <div class="amb-reasoning-path" aria-hidden="true"><span></span><span></span></div>
                <div class="amb-hub-topics">
                  <div>
                    <.icon name="hero-magnifying-glass" class="h-4 w-4" /><strong>Revisit the evidence</strong><span>Explain it in your own words</span>
                  </div>
                  <div>
                    <.icon name="hero-chat-bubble-left-right" class="h-4 w-4" /><strong>Bring back a question</strong><span>Where do you need guidance?</span>
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
                Your subject. Your students. Your guidance.
              </h2>
            </div>
            <p>
              Start with what you teach. Give students a reason to return.<br />Here’s how the proposed programme would work.
            </p>
          </div>
          <div class="amb-steps">
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-peach"><.icon name="hero-window" class="h-6 w-6" /></span><span>01 / MAKE IT YOURS</span>
              </div><h3>Bring students into your hub</h3><p>
                Invite your students to a branded RationalGrid learning space. Use a question from
                your subject as the starting point, with your expertise guiding what they explore.
              </p>
            </article>
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-green"><.icon
                  name="hero-sparkles"
                  class="h-6 w-6"
                /></span><span>02 / GUIDE THE CURIOSITY</span>
              </div><h3>Make the learning visible</h3><p>
                Ask students to explore a question in a shared grid. Follow their questions and
                contributions, discuss the connections they make, and build on that work together
                in the next lesson.
              </p>
            </article>
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-purple"><.icon
                  name="hero-arrow-trending-up"
                  class="h-6 w-6"
                /></span><span>03 / SHARE IN THE GROWTH</span>
              </div><h3>Share in subscription revenue</h3><p>
                Under the proposed model, when a student you introduce takes an eligible paid
                subscription, you receive a share of that revenue. Your teaching gives them a
                reason to use the platform beyond their first visit.
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
            <p class="amb-eyebrow">THE OPPORTUNITY FOR EDUCATORS</p>
            <h2 id="amb-mission-title">
              Bring AI into learning.<br /><em>Make the thinking visible.</em>
            </h2>
            <p>
              You don’t have to fight AI to keep your teaching at the centre. Give students a
              place to use it openly: ask questions, challenge answers, examine evidence, and
              explore different explanations, with your guidance shaping the process.
            </p>
            <p>
              A finished essay can conceal the process behind it, including whether it came from
              a single AI prompt. RationalGrid works like a shared whiteboard: the questions,
              responses, and connections remain visible in a structure you can share, discuss,
              and build on together.
            </p>
            <ul>
              <li>
                <.icon name="hero-check-circle" class="h-5 w-5" /><span><strong>See who asked what.</strong>
                Questions from signed-in students are attributed to their contributors, so you
                can follow their participation and ask them to explain their reasoning.</span>
              </li>
              <li>
                <.icon name="hero-check-circle" class="h-5 w-5" /><span><strong>Explore the structure of an idea.</strong>
                Follow the questions, branches, and AI responses. Use that visible structure to
                discuss assumptions, check sources, and uncover what needs more work.</span>
              </li>
              <li>
                <.icon name="hero-check-circle" class="h-5 w-5" /><span><strong>Build understanding together.</strong>
                Share a grid with your class, explore another student’s question, and add a new
                line of enquiry. Your teaching becomes the starting point for further exploration.</span>
              </li>
            </ul>
            <p>
              Between lessons, students can return to the same grid, revisit a saved explanation,
              and bring a new question back to you. Each visit has a purpose and earlier work
              becomes something to develop further.
            </p>
            <a id="amb-mission-join" href="#join-programme" class="amb-text-link">Help shape what comes next
            <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
          </div>
        </section>

        <section id="how-you-earn" class="amb-section amb-container" aria-labelledby="amb-earn-title">
          <div class="amb-section-heading">
            <div>
              <p class="amb-eyebrow">THE PROPOSED REVENUE-SHARING MODEL</p>
              <h2 id="amb-earn-title">You bring the learners.<br />You share in the revenue.</h2>
            </div>
            <p>
              A share of eligible paid subscriptions from students you introduce.<br />Here’s what that could look like for a tutor.
            </p>
          </div>
          <div class="amb-steps">
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-peach"><.icon
                  name="hero-user-plus"
                  class="h-6 w-6"
                /></span>
                <span>01 / YOU INTRODUCE</span>
              </div>
              <h3>Invite your teaching group</h3>
              <p>
                Imagine you tutor biology. You introduce your students to your RationalGrid hub
                and use a question from this week’s lesson to get them exploring.
              </p>
            </article>
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-green"><.icon
                  name="hero-book-open"
                  class="h-6 w-6"
                /></span>
                <span>02 / THEY SUBSCRIBE</span>
              </div>
              <h3>Students choose to continue</h3>
              <p>
                They revisit explanations, question the evidence, and prepare for your next
                lesson. If they choose an eligible paid subscription through your hub, that
                subscription would count towards your revenue share.
              </p>
            </article>
            <article class="amb-step">
              <div class="amb-step-top">
                <span class="amb-step-icon amb-icon-purple"><.icon
                  name="hero-arrow-trending-up"
                  class="h-6 w-6"
                /></span>
                <span>03 / YOU EARN</span>
              </div>
              <h3>Receive your agreed share</h3>
              <p>
                You would earn a percentage of qualifying subscription revenue under the
                programme’s agreed terms. The opportunity grows with the students who find
                continuing value in the learning you guide.
              </p>
            </article>
          </div>
          <p class="amb-terms-note">
            Illustrative example of the proposed programme. Rates, eligible subscriptions,
            referral attribution, payment schedules, and how long revenue sharing lasts will be
            confirmed before you join. Registering interest does not start an earning arrangement.
          </p>
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
              We’re exploring peer referrals too: introduce a friend who takes an eligible paid
              subscription and receive a share of those fees under the programme’s terms.
              Register as a student for updates on this proposed opportunity.
            </p>
          </div>
          <a
            id="amb-student-join"
            href="#join-programme"
            class="amb-text-link"
            phx-click="select-student"
          >Register as a student <.icon name="hero-arrow-up-right" class="h-4 w-4" /></a>
        </section>

        <section id="join-programme" class="amb-join amb-container" aria-labelledby="amb-join-title">
          <div class="amb-join-copy">
            <p class="amb-eyebrow">BE PART OF THE NEXT CHAPTER</p><h2 id="amb-join-title">
              Take your teaching further.<br /><em>Help shape the programme.</em>
            </h2><p>
              Interested in guiding students through your own RationalGrid hub and sharing in
              subscription revenue? Register for programme updates and early-access opportunities.
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
              <a id="amb-success-explore" href={~p"/community"} class="amb-button amb-button-product">Explore RationalGrid
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
              <p>Leave your email for hub, revenue-share, and early-access updates.</p>
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
                Try a question from your next lesson, save a useful idea, and return to it with
                a follow-up question. The branded hubs and revenue-sharing programme are still
                being developed. <a
                  id="amb-faq-try-link"
                  href={~p"/?focus=grid#start-here"}
                  class="font-semibold underline underline-offset-4"
                >Try RationalGrid today</a>.
              </p>
            </details>
            <details id="amb-faq-product">
              <summary>
                How does my hub connect to RationalGrid?<.icon name="hero-plus" class="h-4 w-4" />
              </summary>
              <p>
                The proposed hub brings the core RationalGrid experience into a learning space
                with your branding and guidance. Students explore connected ideas, challenge
                answers, and revisit their thinking, with your subject and teaching providing
                the direction. You can explore RationalGrid today while we develop the hub
                features with early educators.
              </p>
            </details>
            <details id="amb-faq-return">
              <summary>
                Why would students keep coming back?<.icon name="hero-plus" class="h-4 w-4" />
              </summary>
              <p>
                Give each visit a purpose linked to what you teach. For example, after a lesson
                on evaluating evidence, ask students to explore a claim and bookmark a useful
                explanation. Before the next lesson, they can reopen it, explain the reasoning
                in their own words, and identify what they still don’t understand. Bring that
                question into your next discussion. This is a teaching routine you can try with
                RationalGrid today; we’ll work with early educators to learn what makes it useful
                enough to return to regularly.
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
                RationalGrid brings AI use into a visible learning process. A shared grid lets
                you examine the questions students contributed, the AI responses they explored,
                and the connections they followed. Use that record to ask students to explain
                their choices, challenge a claim, or develop an argument in their own words.
                It gives you material for a conversation about understanding alongside the final
                piece of work. AI can make mistakes, so checking sources and applying your
                institution’s policies remain part of the process.
              </p>
            </details>
            <details id="amb-faq-contributors">
              <summary>
                Can I see who asked each question?<.icon name="hero-plus" class="h-4 w-4" />
              </summary>
              <p>
                Questions and contributions from signed-in students are recorded against their
                contributor identity. The reader shows their profile username when available
                and labels AI responses separately. Ask students to sign in and set a username
                so you can recognise their contributions; anonymous contributions appear as
                guests. In a grid shared with you, this makes it easier to discuss who asked
                what and how the exploration developed.
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
